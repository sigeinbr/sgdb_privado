create table pncp.contratacoes_convocacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial,

	contratacao_id integer not null,
	numero_item integer not null,
	convocacao_externa_id varchar(50) not null,
	cnpj_remanescente varchar(14) not null,
	situacao varchar(2) not null,
	detectada_em timestamp(0) not null,
	dados_json jsonb not null,

	constraint contratacoes_convocacoes_pkey primary key (id),
	constraint contratacoes_convocacoes_ukey unique (contratacao_id, numero_item, convocacao_externa_id, cnpj_remanescente),
	foreign key (contratacao_id) references pncp.contratacoes(id) on delete cascade,
	foreign key (contratacao_id, numero_item) references pncp.contratacoes_itens(contratacao_id, numero_item) on delete cascade
);
comment on table pncp.contratacoes_convocacoes is 'Convocações de fornecedores remanescentes detectadas nas contratações';
comment on column pncp.contratacoes_convocacoes.convocacao_externa_id is 'id da convocação na origem';
comment on column pncp.contratacoes_convocacoes.cnpj_remanescente is 'só dígitos';
comment on column pncp.contratacoes_convocacoes.situacao is 'S, N, NM';
comment on column pncp.contratacoes_convocacoes.dados_json is 'resposta bruta da origem';

grant select, insert, update, delete on pncp.contratacoes_convocacoes to sgisis;
grant select, insert, update, delete on pncp.contratacoes_convocacoes to sgitec;
grant select on pncp.contratacoes_convocacoes to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_convocacoes_contratacao_id on pncp.contratacoes_convocacoes (contratacao_id);
create index ix_contratacoes_convocacoes_dados_json on pncp.contratacoes_convocacoes using gin (dados_json jsonb_path_ops);

create table audit.pncp_contratacoes_convocacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	contratacao_id integer not null,
	numero_item integer not null,
	convocacao_externa_id varchar(50) not null,
	cnpj_remanescente varchar(14) not null,
	situacao varchar(2) not null,
	detectada_em timestamp(0) not null,
	dados_json jsonb not null
);

create index pncp_contratacoes_convocacoes_idx1 on audit.pncp_contratacoes_convocacoes(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_convocacoes_idx2 on audit.pncp_contratacoes_convocacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_convocacoes to sgisis;
grant select on audit.pncp_contratacoes_convocacoes to sgitec;
grant select on audit.pncp_contratacoes_convocacoes to consulta;

create trigger audit_bi before insert on pncp.contratacoes_convocacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_convocacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_convocacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_convocacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_convocacoes for each row execute function audit.func_audit_after();
