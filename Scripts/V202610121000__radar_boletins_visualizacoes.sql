/******************************************************************************************
 * Radar de Licitações - visualizações das edições de boletim (Bloco único, antes do deploy)
 *
 * - pncp.boletins_visualizacoes (+ espelho audit): primeira abertura de cada edição por
 *   usuário, gravada pela API com INSERT ... ON CONFLICT (edicao_id, usuario_login) DO NOTHING
 *
 * Aditivo: o código antigo não lê a tabela. O código novo falha no histórico
 * (GET /boletins/:id/edicoes) sem ela, por isso entra antes do deploy.
 */

/******************************************************************************************
 * TABELA: pncp.boletins_visualizacoes
 */
create table pncp.boletins_visualizacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	edicao_id integer not null,
	usuario_login varchar(50) not null,
	visualizada_em timestamptz not null,
	constraint boletins_visualizacoes_pkey primary key (edicao_id, usuario_login),
	constraint boletins_visualizacoes_edicao_fkey foreign key (edicao_id) references pncp.boletins_edicoes(id) on delete cascade,
	constraint boletins_visualizacoes_usuario_login_fkey foreign key (usuario_login) references adm.usuarios(login) on delete cascade
);

-- FK usuario_login: o delete em cascata a partir de adm.usuarios precisa de índice pelo login
create index boletins_visualizacoes_usuario_login_idx on pncp.boletins_visualizacoes(usuario_login);

grant select, insert, update, delete on pncp.boletins_visualizacoes to sgisis;
grant select, insert, update, delete on pncp.boletins_visualizacoes to sgitec;
grant select on pncp.boletins_visualizacoes to consulta;

/******************************************************************************************
 * TABELA: audit.pncp_boletins_visualizacoes
 */
create table audit.pncp_boletins_visualizacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	edicao_id integer not null,
	usuario_login varchar(50) not null,
	visualizada_em timestamptz not null
);

create index pncp_boletins_visualizacoes_idx1 on audit.pncp_boletins_visualizacoes(dh_audit,oper_audit,usuario_audit);
create index pncp_boletins_visualizacoes_idx2 on audit.pncp_boletins_visualizacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_boletins_visualizacoes to sgisis;
grant select on audit.pncp_boletins_visualizacoes to sgitec;
grant select on audit.pncp_boletins_visualizacoes to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.boletins_visualizacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.boletins_visualizacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on pncp.boletins_visualizacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update on pncp.boletins_visualizacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on pncp.boletins_visualizacoes for each row execute function audit.func_audit_after();
