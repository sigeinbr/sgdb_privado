create table pncp.contas_contratacoes_itens(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null,
	contratacao_item_id integer not null,

	situacao varchar(15) not null,

	constraint contas_contratacoes_itens_pkey primary key (conta_id, contratacao_item_id),
	constraint contas_contratacoes_itens_conta_id_fkey foreign key (conta_id) references adm.contas (id),
	constraint contas_contratacoes_itens_contratacao_item_id_fkey foreign key (contratacao_item_id) references pncp.contratacoes_itens (id) on delete cascade
);
comment on table pncp.contas_contratacoes_itens is 'Itens de contratações que uma conta escolheu acompanhar individualmente';
comment on column pncp.contas_contratacoes_itens.situacao is 'acompanhando, homologado';

grant select, insert, update, delete on pncp.contas_contratacoes_itens to sgisis;
grant select, insert, update, delete on pncp.contas_contratacoes_itens to sgitec;
grant select on pncp.contas_contratacoes_itens to consulta;

create index ix_contas_contratacoes_itens_contratacao_item_id on pncp.contas_contratacoes_itens (contratacao_item_id);

create table audit.pncp_contas_contratacoes_itens (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	contratacao_item_id integer not null,
	situacao varchar(15) not null
);

create index pncp_contas_contratacoes_itens_idx1 on audit.pncp_contas_contratacoes_itens(dh_audit,oper_audit,usuario_audit);
create index pncp_contas_contratacoes_itens_idx2 on audit.pncp_contas_contratacoes_itens(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contas_contratacoes_itens to sgisis;
grant select on audit.pncp_contas_contratacoes_itens to sgitec;
grant select on audit.pncp_contas_contratacoes_itens to consulta;

create trigger audit_bi before insert on pncp.contas_contratacoes_itens for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contas_contratacoes_itens for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contas_contratacoes_itens for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contas_contratacoes_itens for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contas_contratacoes_itens for each row execute function audit.func_audit_after();
