/******************************************************************************************
 * Radar de Licitações — empresas por conta (backfill)
 *
 * Continuação de V202610021000. Deve ir para produção junto com o deploy da aplicação que
 * passa a usar as tabelas novas.
 *
 * Copia o estado por conta para o estado por empresa: uma empresa por conta com CNPJ (os
 * dados da própria conta), os usuários da conta no módulo 97 atribuídos a ela, e os vínculos,
 * menções e envios das tabelas antigas. A cópia fica numa procedure idempotente que permanece
 * no banco: a migration que derrubar as tabelas antigas a chama de novo antes do drop, para
 * pegar o que o job ainda gravou nelas entre esta migration e o deploy — e então a remove.
 */

/******************************************************************************************
 * Procedure: pncp.proc_migrar_empresas_por_conta
 *
 * Idempotente (on conflict do nothing / update só onde o destino está vazio). O trigger
 * audit_bi das tabelas novas é desligado durante a cópia para preservar created_by/created_at
 * de origem — a data de vínculo continua correta — e gravar o ator 'migracao-empresas'
 * (audit.func_audit_before sobrescreveria os dois, pois a migration não roda como sgisis).
 * Os triggers audit_ai continuam ligados: toda linha copiada é auditada normalmente.
 * Ao final confere que nenhuma linha de origem ficou sem destino; se ficou, aborta.
 * Precisa ser executada pelo dono das tabelas (disable trigger).
 */
create or replace procedure pncp.proc_migrar_empresas_por_conta()
 language plpgsql
as $procedure$
declare
  c_ator constant varchar(50) := 'migracao-empresas';
  v_faltantes integer;
begin
  alter table pncp.empresas disable trigger audit_bi;
  alter table pncp.empresas_usuarios disable trigger audit_bi;
  alter table pncp.empresas_contratacoes disable trigger audit_bi;
  alter table pncp.empresas_mencoes disable trigger audit_bi;
  alter table pncp.notificacoes_enviadas disable trigger audit_bi;

  -- a) uma empresa por conta com CNPJ, com os dados da própria conta
  insert into pncp.empresas (conta_id, cnpj, razao_social, nome_fantasia, created_by, updated_by)
  select c.id, regexp_replace(c.cnpj, '[^0-9]', '', 'g'), c.nome, c.nome_fantasia, c_ator, c_ator
    from adm.contas c
   where c.cnpj is not null
  on conflict (conta_id, cnpj) do nothing;

  -- mapa conta -> empresa criada em (a)
  drop table if exists tmp_contas_empresas;
  create temporary table tmp_contas_empresas on commit drop as
  select e.conta_id, e.id as empresa_id
    from pncp.empresas e
    join adm.contas c on (c.id = e.conta_id and regexp_replace(c.cnpj, '[^0-9]', '', 'g') = e.cnpj);

  -- b) usuários que hoje acessam a conta no módulo 97
  insert into pncp.empresas_usuarios (empresa_id, usuario_login, created_by, updated_by)
  select distinct m.empresa_id, vuc.usuario_login, c_ator, c_ator
    from adm.view_usuarios_contas vuc
    join tmp_contas_empresas m on (m.conta_id = vuc.id)
   where vuc.modulo_id = 97
  on conflict (empresa_id, usuario_login) do nothing;

  -- c) vínculos com contratações, preservando monitorada/monitorada_em/mensagens_verificadas_ate
  insert into pncp.empresas_contratacoes
    (empresa_id, contratacao_id, conta_id, monitorada, monitorada_em, mensagens_verificadas_ate,
     created_by, created_at, updated_by)
  select m.empresa_id, cc.contratacao_id, cc.conta_id, cc.monitorada, cc.monitorada_em, cc.mensagens_verificadas_ate,
         cc.created_by, cc.created_at, c_ator
    from pncp.contas_contratacoes cc
    join tmp_contas_empresas m on (m.conta_id = cc.conta_id)
  on conflict (empresa_id, contratacao_id) do nothing;

  -- d) menções, preservando detectado_em/data_hora_mensagem
  insert into pncp.empresas_mencoes
    (empresa_id, mensagem_id, conta_id, contratacao_id, tipo_sinal, trecho, data_hora_mensagem, detectado_em,
     created_by, created_at, updated_by)
  select m.empresa_id, mm.mensagem_id, mm.conta_id, mm.contratacao_id, mm.tipo_sinal, mm.trecho,
         mm.data_hora_mensagem, mm.detectado_em, mm.created_by, mm.created_at, c_ator
    from pncp.contratacoes_mensagens_mencoes mm
    join tmp_contas_empresas m on (m.conta_id = mm.conta_id)
  on conflict (empresa_id, mensagem_id) do nothing;

  -- e) prazo da menção -> mensagem; não sobrescreve o que a aplicação já calculou. Se mais
  -- de uma menção da mesma mensagem tiver prazo, prevalece a de confiança alta, depois a
  -- detectada primeiro.
  update pncp.contratacoes_mensagens cm
     set prazo_em = src.prazo_em,
         prazo_confianca = src.prazo_confianca,
         prazo_trecho_fonte = src.prazo_trecho_fonte
    from (
      select distinct on (mensagem_id) mensagem_id, prazo_em, prazo_confianca, prazo_trecho_fonte
        from pncp.contratacoes_mensagens_mencoes
       where prazo_em is not null
       order by mensagem_id, (prazo_confianca = 'alta') desc, detectado_em
    ) src
   where cm.id = src.mensagem_id
     and cm.prazo_em is null;

  -- f) envios já feitos, preservando enviado_em — sem isto o job reenviaria
  insert into pncp.notificacoes_enviadas
    (empresa_id, mensagem_id, usuario_login, canal, enviado_em, created_by, created_at, updated_by)
  select m.empresa_id, ne.mensagem_id, ne.usuario_login, ne.canal, ne.enviado_em,
         ne.created_by, ne.created_at, c_ator
    from pncp.mencoes_notificacoes_enviadas ne
    join tmp_contas_empresas m on (m.conta_id = ne.conta_id)
  on conflict (empresa_id, mensagem_id, usuario_login, canal) do nothing;

  alter table pncp.empresas enable trigger audit_bi;
  alter table pncp.empresas_usuarios enable trigger audit_bi;
  alter table pncp.empresas_contratacoes enable trigger audit_bi;
  alter table pncp.empresas_mencoes enable trigger audit_bi;
  alter table pncp.notificacoes_enviadas enable trigger audit_bi;

  -- h) conferência: nenhuma linha de origem sem destino (cobre também conta sem CNPJ)
  select count(*) into v_faltantes
    from pncp.contas_contratacoes cc
   where not exists (select 1 from pncp.empresas_contratacoes ec
                       join tmp_contas_empresas m on (m.empresa_id = ec.empresa_id)
                      where m.conta_id = cc.conta_id and ec.contratacao_id = cc.contratacao_id);
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % linha(s) de pncp.contas_contratacoes sem correspondente em pncp.empresas_contratacoes.', v_faltantes;
  end if;

  select count(*) into v_faltantes
    from pncp.contratacoes_mensagens_mencoes mm
   where not exists (select 1 from pncp.empresas_mencoes em
                       join tmp_contas_empresas m on (m.empresa_id = em.empresa_id)
                      where m.conta_id = mm.conta_id and em.mensagem_id = mm.mensagem_id);
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % linha(s) de pncp.contratacoes_mensagens_mencoes sem correspondente em pncp.empresas_mencoes.', v_faltantes;
  end if;

  select count(*) into v_faltantes
    from pncp.mencoes_notificacoes_enviadas ne
   where not exists (select 1 from pncp.notificacoes_enviadas n
                       join tmp_contas_empresas m on (m.empresa_id = n.empresa_id)
                      where m.conta_id = ne.conta_id and n.mensagem_id = ne.mensagem_id
                        and n.usuario_login = ne.usuario_login and n.canal = ne.canal);
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % linha(s) de pncp.mencoes_notificacoes_enviadas sem correspondente em pncp.notificacoes_enviadas.', v_faltantes;
  end if;

  select count(*) into v_faltantes
    from pncp.contratacoes_mensagens_mencoes mm
    join pncp.contratacoes_mensagens cm on (cm.id = mm.mensagem_id)
   where mm.prazo_em is not null
     and cm.prazo_em is null;
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % menção(ões) com prazo cuja mensagem ficou sem prazo_em.', v_faltantes;
  end if;

  raise notice 'Backfill empresas: empresas=%, empresas_usuarios=%, empresas_contratacoes=% (monitoradas=%), empresas_mencoes=%, notificacoes_enviadas=%, mensagens com prazo=%',
    (select count(*) from pncp.empresas),
    (select count(*) from pncp.empresas_usuarios),
    (select count(*) from pncp.empresas_contratacoes),
    (select count(*) from pncp.empresas_contratacoes where monitorada),
    (select count(*) from pncp.empresas_mencoes),
    (select count(*) from pncp.notificacoes_enviadas),
    (select count(*) from pncp.contratacoes_mensagens where prazo_em is not null);
end;
$procedure$;

call pncp.proc_migrar_empresas_por_conta();

/******************************************************************************************
 * Conferência da primeira execução: os campos de cobrança/corte de alerta foram copiados
 * exatamente. (Só aqui — numa reexecução posterior ao deploy a aplicação já pode ter mudado
 * as linhas novas, e a divergência seria legítima.)
 */
do $$
declare
  v_divergentes integer;
begin
  select count(*) into v_divergentes
    from pncp.contas_contratacoes cc
    join pncp.empresas_contratacoes ec on (ec.conta_id = cc.conta_id and ec.contratacao_id = cc.contratacao_id)
   where ec.monitorada is distinct from cc.monitorada
      or ec.monitorada_em is distinct from cc.monitorada_em
      or ec.mensagens_verificadas_ate is distinct from cc.mensagens_verificadas_ate
      or ec.created_at is distinct from cc.created_at;
  if v_divergentes > 0 then
    raise exception 'Backfill empresas: % vínculo(s) copiados com monitorada/monitorada_em/mensagens_verificadas_ate/created_at divergentes.', v_divergentes;
  end if;
end;
$$;
