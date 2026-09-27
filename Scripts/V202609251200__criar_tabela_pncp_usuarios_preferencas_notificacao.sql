/******************************************************************************************
 * TABELA: pncp.usuarios_preferencas_notificacao
 *
 * Guarda somente os desvios do valor padrão de notificação por (usuario, tipo_sinal,
 * canal) — a ausência de uma linha assume o default definido nas regras de decisão de
 * notificação. Evita popular todas as combinações para cada usuário existente.
 * usuario_login referencia adm.usuarios, que é global (sem conta_id) — a preferência é
 * do usuário, não da conta.
 */
create table pncp.usuarios_preferencas_notificacao(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	usuario_login varchar(50) not null,
	tipo_sinal varchar(15) not null,
	canal varchar(10) not null,

	ativo boolean not null,

	constraint usuarios_preferencas_notificacao_pkey primary key (usuario_login, tipo_sinal, canal),
	constraint usuarios_preferencas_notificacao_usuario_login_fkey foreign key (usuario_login) references adm.usuarios (login) on delete cascade,
	constraint usuarios_preferencas_notificacao_tipo_sinal_chk check (tipo_sinal in ('destinatario','cnpj_texto','nome_texto')),
	constraint usuarios_preferencas_notificacao_canal_chk check (canal in ('email','whatsapp'))
);

grant select, insert, update, delete on pncp.usuarios_preferencas_notificacao to sgisis;
grant select, insert, update, delete on pncp.usuarios_preferencas_notificacao to sgitec;
grant select on pncp.usuarios_preferencas_notificacao to consulta;

/******************************************************************************************
 * TABELA: audit.pncp_usuarios_preferencas_notificacao
 */
create table audit.pncp_usuarios_preferencas_notificacao (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	usuario_login varchar(50) not null,
	tipo_sinal varchar(15) not null,
	canal varchar(10) not null,
	ativo boolean not null
);

create index pncp_usuarios_preferencas_notificacao_idx1 on audit.pncp_usuarios_preferencas_notificacao(dh_audit,oper_audit,usuario_audit);
create index pncp_usuarios_preferencas_notificacao_idx2 on audit.pncp_usuarios_preferencas_notificacao(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_usuarios_preferencas_notificacao to sgisis;
grant select on audit.pncp_usuarios_preferencas_notificacao to sgitec;
grant select on audit.pncp_usuarios_preferencas_notificacao to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.usuarios_preferencas_notificacao for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.usuarios_preferencas_notificacao for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.usuarios_preferencas_notificacao for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.usuarios_preferencas_notificacao for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.usuarios_preferencas_notificacao for each row execute function audit.func_audit_after();
