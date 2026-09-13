create table pncp.comprasnet_sessoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	usuario_login varchar(50) not null references adm.usuarios(login),
	token_cifrado text not null,
	expira_em timestamp(0) not null,
	capturado_em timestamp(0) not null,
	renovado_em timestamp(0) null,
	situacao varchar(10) not null,
	identificador_fornecedor text null,
	ultimo_erro text null,

	constraint comprasnet_sessoes_pkey primary key (id)
);
comment on table pncp.comprasnet_sessoes is 'Sessões do Comprasnet capturadas por extensão de navegador, usadas pelo coletor server-side para operar em nome do usuário logado';
comment on column pncp.comprasnet_sessoes.token_cifrado is 'nunca gravado em claro';
comment on column pncp.comprasnet_sessoes.expira_em is 'expiração do JWT';
comment on column pncp.comprasnet_sessoes.capturado_em is 'momento da entrega feita pela extensão';
comment on column pncp.comprasnet_sessoes.renovado_em is 'última rolagem server-side do token';
comment on column pncp.comprasnet_sessoes.situacao is 'ativa, expirada, revogada';
comment on column pncp.comprasnet_sessoes.identificador_fornecedor is 'quem o Comprasnet diz que está logado';
comment on column pncp.comprasnet_sessoes.ultimo_erro is 'motivo da última falha';

grant select, insert, update, delete on pncp.comprasnet_sessoes to sgisis;
grant select, insert, update, delete on pncp.comprasnet_sessoes to sgitec;
grant select on pncp.comprasnet_sessoes to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_comprasnet_sessoes_conta_id_situacao on pncp.comprasnet_sessoes (conta_id, situacao);

create table audit.pncp_comprasnet_sessoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,
	usuario_login varchar(50) not null,
	token_cifrado text not null,
	expira_em timestamp(0) not null,
	capturado_em timestamp(0) not null,
	renovado_em timestamp(0) null,
	situacao varchar(10) not null,
	identificador_fornecedor text null,
	ultimo_erro text null
);

create index pncp_comprasnet_sessoes_idx1 on audit.pncp_comprasnet_sessoes(dh_audit,oper_audit,usuario_audit);
create index pncp_comprasnet_sessoes_idx2 on audit.pncp_comprasnet_sessoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_comprasnet_sessoes to sgisis;
grant select on audit.pncp_comprasnet_sessoes to sgitec;
grant select on audit.pncp_comprasnet_sessoes to consulta;

create trigger audit_bi before insert on pncp.comprasnet_sessoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.comprasnet_sessoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.comprasnet_sessoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.comprasnet_sessoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.comprasnet_sessoes for each row execute function audit.func_audit_after();
