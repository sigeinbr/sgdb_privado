/******************************************************************************************
 * Radar de Licitações — empresas por conta (estrutura)
 *
 * A conta (adm.contas) deixa de ser a empresa monitorada e passa a ser só a unidade de
 * licenciamento. Surge pncp.empresas (CNPJ + razão social procurada nas mensagens), várias
 * por conta, e os vínculos com contratações, menções e controle de envio passam a ser por
 * empresa, em tabelas novas:
 *   pncp.contas_contratacoes            -> pncp.empresas_contratacoes
 *   pncp.contratacoes_mensagens_mencoes -> pncp.empresas_mencoes
 *   pncp.mencoes_notificacoes_enviadas  -> pncp.notificacoes_enviadas
 * O prazo extraído deixa a menção e vai para pncp.contratacoes_mensagens (é propriedade da
 * mensagem, não da empresa citada).
 *
 * Migration aditiva: não quebra o código atual. O backfill está em V202610021100; o drop das
 * tabelas antigas vem numa migration posterior, depois de validado em produção.
 */

/******************************************************************************************
 * TABELA: pncp.empresas
 *
 * Empresa monitorada por uma conta. razao_social é o termo procurado nas mensagens;
 * nome_fantasia é só exibição. O mesmo CNPJ pode existir em contas diferentes.
 * empresas_id_conta_ukey (id, conta_id) é alvo das FKs compostas das tabelas filhas: o banco
 * garante que a empresa referenciada pertence à conta gravada na filha.
 */
create table pncp.empresas(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial,

	conta_id integer not null,
	cnpj varchar(14) not null,
	razao_social text not null,
	nome_fantasia text null,

	constraint empresas_pkey primary key (id),
	constraint empresas_conta_cnpj_ukey unique (conta_id, cnpj),
	constraint empresas_id_conta_ukey unique (id, conta_id),
	constraint empresas_conta_id_fkey foreign key (conta_id) references adm.contas (id),
	constraint empresas_cnpj_chk check (cnpj ~ '^[0-9]{14}$' and adm.func_valida_cnpj(cnpj))
);
comment on table pncp.empresas is
  'Empresa monitorada por uma conta: dona dos vínculos com contratações, das menções e das '
  'notificações. A conta (adm.contas) é só a unidade de licenciamento.';
comment on column pncp.empresas.cnpj is 'só dígitos; imutável pela aplicação';
comment on column pncp.empresas.razao_social is 'termo procurado nas mensagens';
comment on column pncp.empresas.nome_fantasia is 'só exibição';

grant select, insert, update, delete on pncp.empresas to sgisis;
grant select, insert, update, delete on pncp.empresas to sgitec;
grant select on pncp.empresas to consulta;
grant usage on sequence pncp.empresas_id_seq to sgisis;
grant usage on sequence pncp.empresas_id_seq to sgitec;

/******************************************************************************************
 * TABELA: audit.pncp_empresas
 */
create table audit.pncp_empresas (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,

	conta_id integer not null,
	cnpj varchar(14) not null,
	razao_social text not null,
	nome_fantasia text
);

create index pncp_empresas_idx1 on audit.pncp_empresas(dh_audit,oper_audit,usuario_audit);
create index pncp_empresas_idx2 on audit.pncp_empresas(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_empresas to sgisis;
grant select on audit.pncp_empresas to sgitec;
grant select on audit.pncp_empresas to consulta;

create trigger audit_bi before insert on pncp.empresas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.empresas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.empresas for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.empresas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.empresas for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.empresas_usuarios
 *
 * Atribuição usuário <-> empresa: dá acesso à empresa no painel e o recebimento das
 * notificações dela. FK para adm.usuarios com cascade porque adm.usuarios é compartilhada
 * com outros sistemas — sem o cascade, excluir o usuário por outro sistema quebraria aqui.
 */
create table pncp.empresas_usuarios(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	empresa_id integer not null,
	usuario_login varchar(50) not null,

	constraint empresas_usuarios_pkey primary key (empresa_id, usuario_login),
	constraint empresas_usuarios_empresa_id_fkey foreign key (empresa_id) references pncp.empresas (id) on delete cascade,
	constraint empresas_usuarios_usuario_login_fkey foreign key (usuario_login) references adm.usuarios (login) on delete cascade
);
comment on table pncp.empresas_usuarios is
  'Atribuição de usuário a empresa: acesso no painel e recebimento das notificações dela.';

grant select, insert, update, delete on pncp.empresas_usuarios to sgisis;
grant select, insert, update, delete on pncp.empresas_usuarios to sgitec;
grant select on pncp.empresas_usuarios to consulta;

create index ix_empresas_usuarios_usuario_login on pncp.empresas_usuarios (usuario_login);

/******************************************************************************************
 * TABELA: audit.pncp_empresas_usuarios
 */
create table audit.pncp_empresas_usuarios (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	empresa_id integer not null,
	usuario_login varchar(50) not null
);

create index pncp_empresas_usuarios_idx1 on audit.pncp_empresas_usuarios(dh_audit,oper_audit,usuario_audit);
create index pncp_empresas_usuarios_idx2 on audit.pncp_empresas_usuarios(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_empresas_usuarios to sgisis;
grant select on audit.pncp_empresas_usuarios to sgitec;
grant select on audit.pncp_empresas_usuarios to consulta;

create trigger audit_bi before insert on pncp.empresas_usuarios for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.empresas_usuarios for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.empresas_usuarios for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.empresas_usuarios for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.empresas_usuarios for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.empresas_contratacoes  (substitui pncp.contas_contratacoes)
 *
 * Vínculo empresa x contratação. monitorada é a dimensão de cobrança do produto (cobra-se
 * por par empresa+contratação monitorado); monitorada_em é o marco de cobrança e o corte do
 * que gera alerta. conta_id é mantido (FK composta com a empresa) para as consultas
 * continuarem filtrando pelo tenant diretamente.
 */
create table pncp.empresas_contratacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	empresa_id integer not null,
	contratacao_id integer not null,

	conta_id integer not null,
	monitorada boolean not null default false,
	monitorada_em timestamp null,
	mensagens_verificadas_ate timestamp null,

	constraint empresas_contratacoes_pkey primary key (empresa_id, contratacao_id),
	constraint empresas_contratacoes_empresa_fkey foreign key (empresa_id, conta_id) references pncp.empresas (id, conta_id) on delete cascade,
	constraint empresas_contratacoes_contratacao_id_fkey foreign key (contratacao_id) references pncp.contratacoes (id) on delete cascade
);
comment on table pncp.empresas_contratacoes is
  'Vínculo de acompanhamento entre empresa e contratação pública PNCP. monitorada é a '
  'dimensão de cobrança do produto.';
comment on column pncp.empresas_contratacoes.monitorada_em is 'marco de cobrança e corte do que gera alerta';

grant select, insert, update, delete on pncp.empresas_contratacoes to sgisis;
grant select, insert, update, delete on pncp.empresas_contratacoes to sgitec;
grant select on pncp.empresas_contratacoes to consulta;

create index ix_empresas_contratacoes_contratacao_id on pncp.empresas_contratacoes (contratacao_id);
create index ix_empresas_contratacoes_conta_empresa on pncp.empresas_contratacoes (conta_id, empresa_id);

/******************************************************************************************
 * TABELA: audit.pncp_empresas_contratacoes
 */
create table audit.pncp_empresas_contratacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	empresa_id integer not null,
	contratacao_id integer not null,

	conta_id integer not null,
	monitorada boolean not null,
	monitorada_em timestamp,
	mensagens_verificadas_ate timestamp
);

create index pncp_empresas_contratacoes_idx1 on audit.pncp_empresas_contratacoes(dh_audit,oper_audit,usuario_audit);
create index pncp_empresas_contratacoes_idx2 on audit.pncp_empresas_contratacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_empresas_contratacoes to sgisis;
grant select on audit.pncp_empresas_contratacoes to sgitec;
grant select on audit.pncp_empresas_contratacoes to consulta;

create trigger audit_bi before insert on pncp.empresas_contratacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.empresas_contratacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.empresas_contratacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.empresas_contratacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.empresas_contratacoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.empresas_mencoes  (substitui pncp.contratacoes_mensagens_mencoes)
 *
 * Sinal (o mais forte, quando mais de um bate) de que uma mensagem é destinada à empresa:
 * destinatário explícito > CNPJ no texto > razão social no texto. contratacao_id e
 * data_hora_mensagem são denormalizados de pncp.contratacoes_mensagens para o painel não
 * precisar de join. Sem colunas de prazo: o prazo é da mensagem (pncp.contratacoes_mensagens).
 */
create table pncp.empresas_mencoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	empresa_id integer not null,
	mensagem_id integer not null,

	conta_id integer not null,
	contratacao_id integer not null,
	tipo_sinal varchar(15) not null,
	trecho text not null,
	data_hora_mensagem timestamp(0) not null,
	detectado_em timestamp(0) not null,

	constraint empresas_mencoes_pkey primary key (empresa_id, mensagem_id),
	constraint empresas_mencoes_empresa_fkey foreign key (empresa_id, conta_id) references pncp.empresas (id, conta_id) on delete cascade,
	constraint empresas_mencoes_mensagem_id_fkey foreign key (mensagem_id) references pncp.contratacoes_mensagens (id) on delete cascade,
	constraint empresas_mencoes_contratacao_id_fkey foreign key (contratacao_id) references pncp.contratacoes (id) on delete cascade,
	constraint empresas_mencoes_tipo_sinal_chk check (tipo_sinal in ('destinatario','cnpj_texto','nome_texto'))
);
comment on table pncp.empresas_mencoes is
  'Sinal (o mais forte, quando mais de um bate) de que uma mensagem é destinada à empresa: '
  'por destinatário explícito, CNPJ no texto ou razão social no texto.';
comment on column pncp.empresas_mencoes.contratacao_id is 'denormalizado de contratacoes_mensagens, evita join no painel';
comment on column pncp.empresas_mencoes.data_hora_mensagem is 'denormalizado de contratacoes_mensagens, usado no filtro de faixa do painel';

grant select, insert, update, delete on pncp.empresas_mencoes to sgisis;
grant select, insert, update, delete on pncp.empresas_mencoes to sgitec;
grant select on pncp.empresas_mencoes to consulta;

create index ix_empresas_mencoes_contratacao_id on pncp.empresas_mencoes (contratacao_id);
create index ix_empresas_mencoes_empresa_data on pncp.empresas_mencoes (empresa_id, data_hora_mensagem desc);

/******************************************************************************************
 * TABELA: audit.pncp_empresas_mencoes
 */
create table audit.pncp_empresas_mencoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	empresa_id integer not null,
	mensagem_id integer not null,

	conta_id integer not null,
	contratacao_id integer not null,
	tipo_sinal varchar(15) not null,
	trecho text not null,
	data_hora_mensagem timestamp(0) not null,
	detectado_em timestamp(0) not null
);

create index pncp_empresas_mencoes_idx1 on audit.pncp_empresas_mencoes(dh_audit,oper_audit,usuario_audit);
create index pncp_empresas_mencoes_idx2 on audit.pncp_empresas_mencoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_empresas_mencoes to sgisis;
grant select on audit.pncp_empresas_mencoes to sgitec;
grant select on audit.pncp_empresas_mencoes to consulta;

create trigger audit_bi before insert on pncp.empresas_mencoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.empresas_mencoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.empresas_mencoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.empresas_mencoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.empresas_mencoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.notificacoes_enviadas  (substitui pncp.mencoes_notificacoes_enviadas)
 *
 * Uma linha por (menção da empresa, usuário, canal) confirmando que a entrega já ocorreu —
 * impede reenvio. `canal` é o canal efetivamente usado na entrega, não o preferido.
 */
create table pncp.notificacoes_enviadas(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	empresa_id integer not null,
	mensagem_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,

	enviado_em timestamp(0) not null,

	constraint notificacoes_enviadas_pkey primary key (empresa_id, mensagem_id, usuario_login, canal),
	constraint notificacoes_enviadas_mencao_fkey foreign key (empresa_id, mensagem_id) references pncp.empresas_mencoes (empresa_id, mensagem_id) on delete cascade,
	constraint notificacoes_enviadas_usuario_login_fkey foreign key (usuario_login) references adm.usuarios (login) on delete cascade,
	constraint notificacoes_enviadas_canal_chk check (canal in ('email','whatsapp'))
);
comment on column pncp.notificacoes_enviadas.canal is 'canal efetivamente usado na entrega, não o preferido';

grant select, insert, update, delete on pncp.notificacoes_enviadas to sgisis;
grant select, insert, update, delete on pncp.notificacoes_enviadas to sgitec;
grant select on pncp.notificacoes_enviadas to consulta;

/******************************************************************************************
 * TABELA: audit.pncp_notificacoes_enviadas
 */
create table audit.pncp_notificacoes_enviadas (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	empresa_id integer not null,
	mensagem_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,
	enviado_em timestamp(0) not null
);

create index pncp_notificacoes_enviadas_idx1 on audit.pncp_notificacoes_enviadas(dh_audit,oper_audit,usuario_audit);
create index pncp_notificacoes_enviadas_idx2 on audit.pncp_notificacoes_enviadas(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_notificacoes_enviadas to sgisis;
grant select on audit.pncp_notificacoes_enviadas to sgitec;
grant select on audit.pncp_notificacoes_enviadas to consulta;

create trigger audit_bi before insert on pncp.notificacoes_enviadas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.notificacoes_enviadas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.notificacoes_enviadas for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.notificacoes_enviadas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.notificacoes_enviadas for each row execute function audit.func_audit_after();

/******************************************************************************************
 * pncp.contratacoes_mensagens: colunas de prazo extraído
 *
 * Migram de pncp.contratacoes_mensagens_mencoes: o prazo é propriedade da mensagem, não da
 * empresa citada, e a aplicação passa a calculá-lo na importação (mensagens com
 * identificador_destinatario preenchido). Réplica no espelho audit no mesmo script, antes de
 * a aplicação gravar nelas. ADD COLUMN nullable sem default não reescreve a tabela.
 */
alter table pncp.contratacoes_mensagens
    add column prazo_em timestamp(0) null;

alter table pncp.contratacoes_mensagens
    add column prazo_confianca varchar(10) null;

alter table pncp.contratacoes_mensagens
    add column prazo_trecho_fonte text null;

alter table pncp.contratacoes_mensagens
    add constraint contratacoes_mensagens_prazo_confianca_chk
    check (prazo_confianca in ('alta','estimada'));

alter table audit.pncp_contratacoes_mensagens
    add column prazo_em timestamp(0);

alter table audit.pncp_contratacoes_mensagens
    add column prazo_confianca varchar(10);

alter table audit.pncp_contratacoes_mensagens
    add column prazo_trecho_fonte text;

/******************************************************************************************
 * Seed: adm.menus — módulo 97 (Radar de Licitações)
 *
 * Menus de topo "Empresas" (4) e "Usuários" (5). Grupos com todos_menus = true
 * (Administrador) passam a vê-los pela adm.view_usuarios_menus. "Usuários" é a rota de
 * administração e "Empresas" é o cadastro de empresas da conta: nenhum dos dois é liberado
 * aos grupos com todos_menus = false. Os grupos "Usuário" do módulo ganham "Menções".
 */
insert into adm.menus (modulo_id, descricao, rota, ordem)
values (97, 'Empresas', 'empresas', 4),
       (97, 'Usuários', 'usuarios', 5)
on conflict (modulo_id, menu_pai_id, descricao) do nothing;

insert into adm.grupos_permissoes_menus (grupo_permissao_id, menu_id)
select gp.id, m.id
  from adm.grupos_permissoes gp
  join adm.menus m on (m.modulo_id = gp.modulo_id and m.rota = 'mencoes')
 where gp.modulo_id = 97
   and gp.descricao = 'Usuário'
on conflict (grupo_permissao_id, menu_id) do nothing;

/******************************************************************************************
 * Procedure: adm.proc_gerar_grupos_permissoes_padroes
 *
 * Ajuste: o grupo "Usuário" do módulo 97 passa a ser vinculado também ao menu "Menções"
 * (rota 'mencoes'), além de "Contratações" — contas novas ganham o mesmo acesso que o
 * seed acima dá às existentes.
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

            insert into adm.grupos_permissoes_menus (grupo_permissao_id, menu_id)
            select gp.id, m.id
              from adm.grupos_permissoes gp
              join adm.menus m on (m.modulo_id = gp.modulo_id and m.rota in ('contratacoes','mencoes'))
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
