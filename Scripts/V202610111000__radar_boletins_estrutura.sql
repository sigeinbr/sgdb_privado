/******************************************************************************************
 * Radar de Licitações - boletins inteligentes (Bloco 1 - estrutura aditiva, antes do deploy)
 *
 * - pncp.boletins, pncp.boletins_edicoes, pncp.boletins_edicoes_itens,
 *   pncp.boletins_notificacoes (+ espelhos audit)
 * - pncp.usuarios_preferencas_notificacao: tipo_sinal aceita 'boletim'
 * - limite_boletins em adm.planos, adm.assinaturas e adm.cobrancas (+ carga)
 * - menu 'boletins' no módulo 97, vinculado aos grupos que têm 'pesquisa'
 *
 * adm.assinaturas.limite_boletins entra NULLABLE e assinaturas_proximo_chk não muda aqui:
 * o código antigo grava assinaturas sem conhecer a coluna. O NOT NULL e o CHECK estendido
 * vêm em migration posterior, aplicada somente depois do deploy do código novo (Bloco 2).
 */

/******************************************************************************************
 * TABELA: pncp.boletins
 */
create table pncp.boletins(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial primary key,
	empresa_id integer not null,
	nome varchar(100) not null,
	filtros jsonb not null,
	horarios smallint[] not null,
	ativo boolean default true not null,
	constraint boletins_empresa_fkey foreign key (empresa_id) references pncp.empresas(id) on delete cascade,
	constraint boletins_empresa_nome_ukey unique (empresa_id, nome),
	constraint boletins_horarios_chk check (cardinality(horarios) between 1 and 3 and horarios <@ '{7,12,18}'::smallint[])
);

create index boletins_ativo_idx on pncp.boletins(ativo) where ativo;

grant select, insert, update, delete on pncp.boletins to sgisis;
grant select, insert, update, delete on pncp.boletins to sgitec;
grant select on pncp.boletins to consulta;
grant usage, select on sequence pncp.boletins_id_seq to sgisis;
grant usage, select on sequence pncp.boletins_id_seq to sgitec;

create table audit.pncp_boletins (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	empresa_id integer not null,
	nome varchar(100) not null,
	filtros jsonb not null,
	horarios smallint[] not null,
	ativo boolean not null
);

create index pncp_boletins_idx1 on audit.pncp_boletins(dh_audit,oper_audit,usuario_audit);
create index pncp_boletins_idx2 on audit.pncp_boletins(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_boletins to sgisis;
grant select on audit.pncp_boletins to sgitec;
grant select on audit.pncp_boletins to consulta;

create trigger audit_bi before insert on pncp.boletins for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.boletins for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on pncp.boletins for each row execute function audit.func_audit_after();
create trigger audit_au after update on pncp.boletins for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on pncp.boletins for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.boletins_edicoes
 */
create table pncp.boletins_edicoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial primary key,
	boletim_id integer not null,
	numero integer not null,
	gerada_em timestamptz not null,
	origem varchar(10) not null,
	horario smallint null,
	notificar boolean not null,
	qtd_novas integer not null,
	qtd_atualizadas integer not null,
	truncada boolean not null,
	constraint boletins_edicoes_boletim_fkey foreign key (boletim_id) references pncp.boletins(id) on delete cascade,
	constraint boletins_edicoes_boletim_numero_ukey unique (boletim_id, numero),
	constraint boletins_edicoes_origem_chk check (origem in ('cadastro', 'agendada')),
	constraint boletins_edicoes_horario_chk check (horario in (7, 12, 18))
);

create index boletins_edicoes_notificar_idx on pncp.boletins_edicoes(gerada_em) where notificar;

grant select, insert, update, delete on pncp.boletins_edicoes to sgisis;
grant select, insert, update, delete on pncp.boletins_edicoes to sgitec;
grant select on pncp.boletins_edicoes to consulta;
grant usage, select on sequence pncp.boletins_edicoes_id_seq to sgisis;
grant usage, select on sequence pncp.boletins_edicoes_id_seq to sgitec;

create table audit.pncp_boletins_edicoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	boletim_id integer not null,
	numero integer not null,
	gerada_em timestamptz not null,
	origem varchar(10) not null,
	horario smallint null,
	notificar boolean not null,
	qtd_novas integer not null,
	qtd_atualizadas integer not null,
	truncada boolean not null
);

create index pncp_boletins_edicoes_idx1 on audit.pncp_boletins_edicoes(dh_audit,oper_audit,usuario_audit);
create index pncp_boletins_edicoes_idx2 on audit.pncp_boletins_edicoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_boletins_edicoes to sgisis;
grant select on audit.pncp_boletins_edicoes to sgitec;
grant select on audit.pncp_boletins_edicoes to consulta;

create trigger audit_bi before insert on pncp.boletins_edicoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.boletins_edicoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on pncp.boletins_edicoes for each row execute function audit.func_audit_after();
create trigger audit_au after update on pncp.boletins_edicoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on pncp.boletins_edicoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.boletins_edicoes_itens
 */
create table pncp.boletins_edicoes_itens(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	edicao_id integer not null,
	numero_controle_pncp varchar(40) not null,
	dados jsonb not null,
	constraint boletins_edicoes_itens_pkey primary key (edicao_id, numero_controle_pncp),
	constraint boletins_edicoes_itens_edicao_fkey foreign key (edicao_id) references pncp.boletins_edicoes(id) on delete cascade
);

create index boletins_edicoes_itens_controle_idx on pncp.boletins_edicoes_itens(numero_controle_pncp, edicao_id desc);

grant select, insert, update, delete on pncp.boletins_edicoes_itens to sgisis;
grant select, insert, update, delete on pncp.boletins_edicoes_itens to sgitec;
grant select on pncp.boletins_edicoes_itens to consulta;

create table audit.pncp_boletins_edicoes_itens (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	edicao_id integer not null,
	numero_controle_pncp varchar(40) not null,
	dados jsonb not null
);

create index pncp_boletins_edicoes_itens_idx1 on audit.pncp_boletins_edicoes_itens(dh_audit,oper_audit,usuario_audit);
create index pncp_boletins_edicoes_itens_idx2 on audit.pncp_boletins_edicoes_itens(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_boletins_edicoes_itens to sgisis;
grant select on audit.pncp_boletins_edicoes_itens to sgitec;
grant select on audit.pncp_boletins_edicoes_itens to consulta;

create trigger audit_bi before insert on pncp.boletins_edicoes_itens for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.boletins_edicoes_itens for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on pncp.boletins_edicoes_itens for each row execute function audit.func_audit_after();
create trigger audit_au after update on pncp.boletins_edicoes_itens for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on pncp.boletins_edicoes_itens for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.boletins_notificacoes
 */
create table pncp.boletins_notificacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	edicao_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,
	enviado_em timestamptz not null,
	destinatario varchar(150) not null,
	constraint boletins_notificacoes_pkey primary key (edicao_id, usuario_login, canal),
	constraint boletins_notificacoes_edicao_fkey foreign key (edicao_id) references pncp.boletins_edicoes(id) on delete cascade,
	constraint boletins_notificacoes_usuario_login_fkey foreign key (usuario_login) references adm.usuarios(login) on delete cascade,
	constraint boletins_notificacoes_canal_chk check (canal in ('email', 'whatsapp'))
);

-- FK usuario_login: o delete em cascata a partir de adm.usuarios precisa de índice pelo login
create index boletins_notificacoes_usuario_login_idx on pncp.boletins_notificacoes(usuario_login);

grant select, insert, update, delete on pncp.boletins_notificacoes to sgisis;
grant select, insert, update, delete on pncp.boletins_notificacoes to sgitec;
grant select on pncp.boletins_notificacoes to consulta;

create table audit.pncp_boletins_notificacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	edicao_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,
	enviado_em timestamptz not null,
	destinatario varchar(150) not null
);

create index pncp_boletins_notificacoes_idx1 on audit.pncp_boletins_notificacoes(dh_audit,oper_audit,usuario_audit);
create index pncp_boletins_notificacoes_idx2 on audit.pncp_boletins_notificacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_boletins_notificacoes to sgisis;
grant select on audit.pncp_boletins_notificacoes to sgitec;
grant select on audit.pncp_boletins_notificacoes to consulta;

create trigger audit_bi before insert on pncp.boletins_notificacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.boletins_notificacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on pncp.boletins_notificacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update on pncp.boletins_notificacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on pncp.boletins_notificacoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * pncp.usuarios_preferencas_notificacao - tipo_sinal aceita 'boletim'
 */
alter table pncp.usuarios_preferencas_notificacao drop constraint usuarios_preferencas_notificacao_tipo_sinal_chk;
alter table pncp.usuarios_preferencas_notificacao add constraint usuarios_preferencas_notificacao_tipo_sinal_chk
	check (tipo_sinal in ('destinatario', 'cnpj_texto', 'nome_texto', 'prazo_destacado', 'boletim'));

/******************************************************************************************
 * Limite de boletins por plano (acompanha o limite de contratações na carga inicial)
 */

-- adm.planos: NULL somente no plano 'personalizado', como os demais limites
alter table adm.planos add column limite_boletins integer null;
alter table audit.adm_planos add column limite_boletins integer null;

update adm.planos set limite_boletins = limite_contratacoes;

alter table adm.planos drop constraint planos_personalizado_chk;
alter table adm.planos add constraint planos_personalizado_chk check (
	(codigo = 'personalizado' and preco_unitario is not null and limite_contratacoes is null and limite_empresas is null
	 and limite_usuarios is null and limite_boletins is null and preco_mensal is null)
	or
	(codigo <> 'personalizado' and preco_unitario is null and limite_contratacoes is not null and limite_empresas is not null
	 and limite_usuarios is not null and limite_boletins is not null and preco_mensal is not null)
);

-- adm.assinaturas: NOT NULL e assinaturas_proximo_chk estendido ficam para o Bloco 2
alter table adm.assinaturas add column limite_boletins integer null;
alter table adm.assinaturas add column proximo_limite_boletins integer null;
alter table audit.adm_assinaturas add column limite_boletins integer null;
alter table audit.adm_assinaturas add column proximo_limite_boletins integer null;

update adm.assinaturas
   set limite_boletins = limite_contratacoes,
       proximo_limite_boletins = proximo_limite_contratacoes;

-- adm.cobrancas: limite do ciclo cobrado
alter table adm.cobrancas add column limite_boletins integer null;
alter table audit.adm_cobrancas add column limite_boletins integer null;

update adm.cobrancas set limite_boletins = limite_contratacoes;

/******************************************************************************************
 * adm.menus - rota 'boletins' no módulo 97, logo após 'Pesquisas (Beta)'
 *
 * Ordem: 1 Minha Conta, 2 Pesquisas (Beta), 3 Boletins, 4 Contratações, 5 Mensagens.
 */
insert into adm.menus (modulo_id, descricao, rota)
values (97, 'Boletins', 'boletins')
on conflict (modulo_id, menu_pai_id, descricao) do nothing;

update adm.menus set ordem = 3 where modulo_id = 97 and menu_pai_id is null and rota = 'boletins';
update adm.menus set ordem = 4 where modulo_id = 97 and menu_pai_id is null and rota = 'contratacoes';
update adm.menus set ordem = 5 where modulo_id = 97 and menu_pai_id is null and rota = 'mencoes';

-- Todo grupo que tem 'pesquisa' passa a ter 'boletins'
insert into adm.grupos_permissoes_menus (grupo_permissao_id, menu_id)
select gpm.grupo_permissao_id, mb.id
  from adm.grupos_permissoes_menus gpm
  join adm.menus mp on (mp.id = gpm.menu_id and mp.modulo_id = 97 and mp.rota = 'pesquisa')
  join adm.menus mb on (mb.modulo_id = 97 and mb.rota = 'boletins')
on conflict (grupo_permissao_id, menu_id) do nothing;

/******************************************************************************************
 * Procedure: adm.proc_gerar_grupos_permissoes_padroes
 *
 * Ajuste: o grupo "Usuário" do módulo 97 criado para contas novas também recebe o menu
 * "Boletins" (rota 'boletins'), junto de "Pesquisas (Beta)", "Contratações" e "Mensagens".
 */
create or replace procedure adm.proc_gerar_grupos_permissoes_padroes(in p_conta integer, in p_modulo integer)
 language plpgsql
as $procedure$
declare
  v_grupo   varchar(100);
  v_usuario varchar(100);
  r         record;
begin
  if exists(select * from adm.contas where id = p_conta) then
    if exists(select * from adm.modulos where id = p_modulo) then

      if p_modulo = 1 then
        if exists(select * from adm.contas_modulos where conta_id = p_conta and modulo_id = p_modulo) then
          v_grupo = 'Administrador';
          if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
            insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
            values (v_grupo, p_conta, p_modulo, true, true, true);
          end if;

          v_usuario = 'admin';
          if exists(select * from adm.usuarios where login = v_usuario) then
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end if;

          for r in
            select gpu.usuario_login
            from adm.grupos_permissoes gp
            join adm.grupos_permissoes_usuarios gpu on (gp.id = gpu.grupo_permissao_id)
            where gp.descricao = 'Administrador' and gp.modulo_id = 1 and gp.conta_id = p_conta
          loop
            v_usuario = r.usuario_login;
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end loop;
        end if;
      end if;

      if p_modulo <> 1 then
        if exists(select * from adm.contas_modulos where conta_id = p_conta and modulo_id = p_modulo) then
          v_grupo = 'Administrador';
          if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
            insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
            values (v_grupo, p_conta, p_modulo, true, true, true);
          end if;

          for r in
            select gpu.usuario_login
            from adm.grupos_permissoes gp
            join adm.grupos_permissoes_usuarios gpu on (gp.id = gpu.grupo_permissao_id)
            where gp.descricao = 'Administrador' and gp.modulo_id = 1 and gp.conta_id = p_conta
          loop
            v_usuario = r.usuario_login;
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end loop;

          if p_modulo = 97 then
            v_grupo = 'Usuário';
            if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
              insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
              values (v_grupo, p_conta, p_modulo, false, true, true);
            end if;

            -- Vincula os menus "Pesquisas (Beta)", "Boletins", "Contratações" e "Mensagens"
            insert into adm.grupos_permissoes_menus (grupo_permissao_id, menu_id)
            select gp.id, m.id
              from adm.grupos_permissoes gp
              join adm.menus m on (m.modulo_id = gp.modulo_id and m.rota in ('pesquisa', 'boletins', 'contratacoes', 'mencoes'))
             where gp.conta_id = p_conta and gp.descricao = v_grupo and gp.modulo_id = p_modulo
            on conflict (grupo_permissao_id, menu_id) do nothing;
          else
            v_grupo = 'Consultas e Relatórios';
            if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
              insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
              values (v_grupo, p_conta, p_modulo, false, true, true);
            end if;
          end if;
        end if;
      end if;

    end if;
  end if;
end;
$procedure$;
