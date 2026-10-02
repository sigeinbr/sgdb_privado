/******************************************************************************************
 * Ajuste pontual — corrige checksum mismatch de V202610021100 na VPS
 *
 * Causa: V202610021100 foi editada (commit d4d299f) depois de já ter sido aplicada na VPS
 * com o corpo antigo da procedure pncp.proc_migrar_empresas_por_conta() (sem parametro).
 * O Flyway não reexecuta migration ja aplicada, entao so corrigir o checksum deixaria a
 * procedure na VPS sem a sobrecarga (p_repassada boolean), que o V202610021200 (ainda
 * pendente) precisa para chamar pncp.proc_migrar_empresas_por_conta(true) e depois dropar.
 *
 * Este script leva o banco da VPS ao mesmo estado de catalogo que uma aplicacao do zero do
 * V202610021100 atual produziria — sem reprocessar o backfill de dados (ja feito na 1a
 * execucao) — e corrige o checksum no flyway_schema_history. Nao apaga nem reescreve
 * nenhuma linha de negocio.
 *
 * Rodar uma unica vez na VPS, antes do proximo deploy:
 *   docker exec -i postgres-sigein psql -U sgidba -d target \
 *     -f Scripts/ajustes_pontuais_fix_checksum_202610021100.sql
 *
 * Se flyway_schema_history nao estiver no schema "public", ajuste as duas referencias
 * abaixo antes de rodar.
 */

begin;

-- 0) Trava de seguranca: so segue se o checksum atual for exatamente o reportado como
--    "Applied to database" no erro do Flyway. Evita rodar isto contra um banco que ja
--    esteja em outro estado.
do $$
begin
  if not exists (
    select 1 from public.flyway_schema_history
     where version = '202610021100' and checksum = 1533281255 and success = true
  ) then
    raise exception 'Checksum atual de 202610021100 nao e o esperado (1533281255) -- abortando. Confira manualmente antes de prosseguir.';
  end if;
end $$;

-- 1) Cria a sobrecarga nova da procedure (com p_repassada), identica ao que esta hoje em
--    Scripts/V202610021100__pncp_empresas_backfill.sql. E aditivo: nao mexe na sobrecarga
--    sem parametro ja existente na VPS.
create or replace procedure pncp.proc_migrar_empresas_por_conta(p_repassada boolean default false)
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

  drop table if exists tmp_empresas_novas, tmp_contas_empresas, tmp_pend_contratacoes, tmp_pend_mencoes, tmp_pend_notificacoes;

  -- a) uma empresa por conta com CNPJ, com os dados da propria conta
  create temporary table tmp_empresas_novas (id integer) on commit drop;

  with novas as (
    insert into pncp.empresas (conta_id, cnpj, razao_social, nome_fantasia, created_by, updated_by)
    select c.id, regexp_replace(c.cnpj, '[^0-9]', '', 'g'), c.nome, c.nome_fantasia, c_ator, c_ator
      from adm.contas c
     where c.cnpj is not null
       and (not p_repassada
            or not exists (select 1 from audit.pncp_empresas ae where ae.conta_id = c.id))
    on conflict (conta_id, cnpj) do nothing
    returning id
  )
  insert into tmp_empresas_novas select id from novas;

  -- mapa conta -> empresa com o CNPJ da conta
  create temporary table tmp_contas_empresas on commit drop as
  select e.conta_id, e.id as empresa_id
    from pncp.empresas e
    join adm.contas c on (c.id = e.conta_id and regexp_replace(c.cnpj, '[^0-9]', '', 'g') = e.cnpj);

  -- b) usuarios que hoje acessam a conta no modulo 97 (na repassada, so das empresas criadas
  -- em (a) nesta execucao -- nas demais a atribuicao ja e gerida pela aplicacao)
  insert into pncp.empresas_usuarios (empresa_id, usuario_login, created_by, updated_by)
  select distinct m.empresa_id, vuc.usuario_login, c_ator, c_ator
    from adm.view_usuarios_contas vuc
    join tmp_contas_empresas m on (m.conta_id = vuc.id)
   where vuc.modulo_id = 97
     and (not p_repassada or m.empresa_id in (select id from tmp_empresas_novas))
  on conflict (empresa_id, usuario_login) do nothing;

  -- linhas de origem a copiar (calculadas antes da copia, para a conferencia valer sobre elas)
  create temporary table tmp_pend_contratacoes on commit drop as
  select cc.conta_id, cc.contratacao_id
    from pncp.contas_contratacoes cc
   where not p_repassada
      or not exists (select 1 from audit.pncp_empresas_contratacoes a
                      where a.conta_id = cc.conta_id and a.contratacao_id = cc.contratacao_id);

  create temporary table tmp_pend_mencoes on commit drop as
  select mm.conta_id, mm.mensagem_id
    from pncp.contratacoes_mensagens_mencoes mm
   where not p_repassada
      or not exists (select 1 from audit.pncp_empresas_mencoes a
                      where a.conta_id = mm.conta_id and a.mensagem_id = mm.mensagem_id);

  create temporary table tmp_pend_notificacoes on commit drop as
  select ne.conta_id, ne.mensagem_id, ne.usuario_login, ne.canal
    from pncp.mencoes_notificacoes_enviadas ne
   where not p_repassada
      or not exists (select 1 from audit.pncp_notificacoes_enviadas a
                       join (select distinct id, conta_id from audit.pncp_empresas) ae on (ae.id = a.empresa_id)
                      where ae.conta_id = ne.conta_id and a.mensagem_id = ne.mensagem_id
                        and a.usuario_login = ne.usuario_login and a.canal = ne.canal);

  -- c) vinculos com contratacoes, preservando monitorada/monitorada_em/mensagens_verificadas_ate
  insert into pncp.empresas_contratacoes
    (empresa_id, contratacao_id, conta_id, monitorada, monitorada_em, mensagens_verificadas_ate,
     created_by, created_at, updated_by)
  select m.empresa_id, cc.contratacao_id, cc.conta_id, cc.monitorada, cc.monitorada_em, cc.mensagens_verificadas_ate,
         cc.created_by, cc.created_at, c_ator
    from pncp.contas_contratacoes cc
    join tmp_pend_contratacoes p using (conta_id, contratacao_id)
    join tmp_contas_empresas m on (m.conta_id = cc.conta_id)
  on conflict (empresa_id, contratacao_id) do nothing;

  -- d) mencoes, preservando detectado_em/data_hora_mensagem
  insert into pncp.empresas_mencoes
    (empresa_id, mensagem_id, conta_id, contratacao_id, tipo_sinal, trecho, data_hora_mensagem, detectado_em,
     created_by, created_at, updated_by)
  select m.empresa_id, mm.mensagem_id, mm.conta_id, mm.contratacao_id, mm.tipo_sinal, mm.trecho,
         mm.data_hora_mensagem, mm.detectado_em, mm.created_by, mm.created_at, c_ator
    from pncp.contratacoes_mensagens_mencoes mm
    join tmp_pend_mencoes p using (conta_id, mensagem_id)
    join tmp_contas_empresas m on (m.conta_id = mm.conta_id)
  on conflict (empresa_id, mensagem_id) do nothing;

  -- e) prazo da mencao -> mensagem; nao sobrescreve o que a aplicacao ja calculou.
  update pncp.contratacoes_mensagens cm
     set prazo_em = src.prazo_em,
         prazo_confianca = src.prazo_confianca,
         prazo_trecho_fonte = src.prazo_trecho_fonte
    from (
      select distinct on (mm.mensagem_id) mm.mensagem_id, mm.prazo_em, mm.prazo_confianca, mm.prazo_trecho_fonte
        from pncp.contratacoes_mensagens_mencoes mm
        join tmp_pend_mencoes p using (conta_id, mensagem_id)
       where mm.prazo_em is not null
       order by mm.mensagem_id, (mm.prazo_confianca = 'alta') desc, mm.detectado_em
    ) src
   where cm.id = src.mensagem_id
     and cm.prazo_em is null;

  -- f) envios ja feitos, preservando enviado_em -- sem isto o job reenviaria
  insert into pncp.notificacoes_enviadas
    (empresa_id, mensagem_id, usuario_login, canal, enviado_em, created_by, created_at, updated_by)
  select m.empresa_id, ne.mensagem_id, ne.usuario_login, ne.canal, ne.enviado_em,
         ne.created_by, ne.created_at, c_ator
    from pncp.mencoes_notificacoes_enviadas ne
    join tmp_pend_notificacoes p using (conta_id, mensagem_id, usuario_login, canal)
    join tmp_contas_empresas m on (m.conta_id = ne.conta_id)
  on conflict (empresa_id, mensagem_id, usuario_login, canal) do nothing;

  alter table pncp.empresas enable trigger audit_bi;
  alter table pncp.empresas_usuarios enable trigger audit_bi;
  alter table pncp.empresas_contratacoes enable trigger audit_bi;
  alter table pncp.empresas_mencoes enable trigger audit_bi;
  alter table pncp.notificacoes_enviadas enable trigger audit_bi;

  -- h) conferencia: nenhuma linha pendente sem destino.
  select count(*) into v_faltantes
    from tmp_pend_contratacoes p
   where (not p_repassada or exists (select 1 from tmp_contas_empresas m where m.conta_id = p.conta_id))
     and not exists (select 1 from pncp.empresas_contratacoes ec
                      where ec.conta_id = p.conta_id and ec.contratacao_id = p.contratacao_id);
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % linha(s) de pncp.contas_contratacoes sem correspondente em pncp.empresas_contratacoes.', v_faltantes;
  end if;

  select count(*) into v_faltantes
    from tmp_pend_mencoes p
   where (not p_repassada or exists (select 1 from tmp_contas_empresas m where m.conta_id = p.conta_id))
     and not exists (select 1 from pncp.empresas_mencoes em
                      where em.conta_id = p.conta_id and em.mensagem_id = p.mensagem_id);
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % linha(s) de pncp.contratacoes_mensagens_mencoes sem correspondente em pncp.empresas_mencoes.', v_faltantes;
  end if;

  select count(*) into v_faltantes
    from tmp_pend_notificacoes p
   where (not p_repassada or exists (select 1 from tmp_contas_empresas m where m.conta_id = p.conta_id))
     and not exists (select 1 from pncp.notificacoes_enviadas n
                       join tmp_contas_empresas m on (m.empresa_id = n.empresa_id)
                      where m.conta_id = p.conta_id and n.mensagem_id = p.mensagem_id
                        and n.usuario_login = p.usuario_login and n.canal = p.canal);
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % linha(s) de pncp.mencoes_notificacoes_enviadas sem correspondente em pncp.notificacoes_enviadas.', v_faltantes;
  end if;

  select count(*) into v_faltantes
    from pncp.contratacoes_mensagens_mencoes mm
    join tmp_pend_mencoes p using (conta_id, mensagem_id)
    join pncp.contratacoes_mensagens cm on (cm.id = mm.mensagem_id)
   where mm.prazo_em is not null
     and cm.prazo_em is null;
  if v_faltantes > 0 then
    raise exception 'Backfill empresas: % mencao(oes) com prazo cuja mensagem ficou sem prazo_em.', v_faltantes;
  end if;

  raise notice 'Backfill empresas (repassada=%): pendentes contratacoes=%, mencoes=%, notificacoes=%; totais empresas=%, empresas_usuarios=%, empresas_contratacoes=% (monitoradas=%), empresas_mencoes=%, notificacoes_enviadas=%, mensagens com prazo=%',
    p_repassada,
    (select count(*) from tmp_pend_contratacoes),
    (select count(*) from tmp_pend_mencoes),
    (select count(*) from tmp_pend_notificacoes),
    (select count(*) from pncp.empresas),
    (select count(*) from pncp.empresas_usuarios),
    (select count(*) from pncp.empresas_contratacoes),
    (select count(*) from pncp.empresas_contratacoes where monitorada),
    (select count(*) from pncp.empresas_mencoes),
    (select count(*) from pncp.notificacoes_enviadas),
    (select count(*) from pncp.contratacoes_mensagens where prazo_em is not null);
end;
$procedure$;

-- 2) Remove a sobrecarga antiga (sem parametro), orfa desde a 1a aplicacao desta migration.
--    Nada mais a referencia; o ambiente onde a cadeia inteira ja rodou com o arquivo novo
--    (local) nunca teve essa versao. So cosmetico -- nao afeta o V202610021200.
drop procedure if exists pncp.proc_migrar_empresas_por_conta();

-- 3) Corrige o checksum no historico do Flyway para o valor do arquivo atual (o mesmo que
--    o erro reportou como "Resolved locally"). Nao reexecuta a migration, nao toca em
--    nenhuma linha de dado de negocio.
update public.flyway_schema_history
   set checksum = 876876423
 where version = '202610021100'
   and success = true;

commit;
