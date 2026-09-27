/******************************************************************************************
 * TABELA: pncp.alertas_operacionais
 *
 * Debounce de alertas de infraestrutura (ex.: sessão do WAHA indisponível): antes de
 * disparar um novo aviso para RADAR_ALERTA_EMAIL, o job confere se já passou 1h desde o
 * último enviado_em daquela chave. Não é dado de negócio por conta — é estado interno do
 * job, por isso `chave` é a própria identidade do registro, sem id substituto.
 */
create table pncp.alertas_operacionais(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	chave text not null,

	enviado_em timestamp(0) not null,

	constraint alertas_operacionais_pkey primary key (chave)
);

grant select, insert, update, delete on pncp.alertas_operacionais to sgisis;
grant select, insert, update, delete on pncp.alertas_operacionais to sgitec;
grant select on pncp.alertas_operacionais to consulta;

/******************************************************************************************
 * TABELA: audit.pncp_alertas_operacionais
 */
create table audit.pncp_alertas_operacionais (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	chave text not null,
	enviado_em timestamp(0) not null
);

create index pncp_alertas_operacionais_idx1 on audit.pncp_alertas_operacionais(dh_audit,oper_audit,usuario_audit);
create index pncp_alertas_operacionais_idx2 on audit.pncp_alertas_operacionais(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_alertas_operacionais to sgisis;
grant select on audit.pncp_alertas_operacionais to sgitec;
grant select on audit.pncp_alertas_operacionais to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.alertas_operacionais for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.alertas_operacionais for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.alertas_operacionais for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.alertas_operacionais for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.alertas_operacionais for each row execute function audit.func_audit_after();
