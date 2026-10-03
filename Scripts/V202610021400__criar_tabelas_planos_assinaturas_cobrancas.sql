-- Radar de Licitacoes -- planos, assinaturas, cobrancas e controles de conta.
-- Dados financeiros: diferente do padrao do projeto, sgisis/sgitec NAO recebem
-- delete nas 5 tabelas abaixo (so sgidba, dono do schema, pode apagar linha).

/******************************************************************************************
 * TABELA: adm.planos
 */
create table adm.planos(
	created_by            varchar(50) default current_user not null,
	created_at             timestamp(0) default current_timestamp not null,
	updated_by            varchar(50) default current_user not null,
	updated_at             timestamp(0) default current_timestamp not null,
	deleted_by            varchar(50) null,
	codigo                text not null,
	nome                  text not null,
	limite_contratacoes   integer null,
	limite_empresas       integer null,
	limite_usuarios       integer null,
	preco_mensal          numeric(12,2) null,
	preco_unitario        numeric(12,2) null,
	contratavel           boolean not null,
	ordem                 smallint not null,
	constraint planos_pkey primary key (codigo),
	constraint planos_personalizado_chk check (
		(codigo = 'personalizado' and preco_unitario is not null
			and limite_contratacoes is null and limite_empresas is null and limite_usuarios is null and preco_mensal is null)
		or
		(codigo <> 'personalizado' and preco_unitario is null
			and limite_contratacoes is not null and limite_empresas is not null and limite_usuarios is not null and preco_mensal is not null)
	)
);

grant select, insert, update on adm.planos to sgisis;
grant select, insert, update on adm.planos to sgitec;
grant select on adm.planos to consulta;

insert into adm.planos (codigo, nome, limite_contratacoes, limite_empresas, limite_usuarios, preco_mensal, preco_unitario, contratavel, ordem) values
	('trial', 'Trial', 5, 1, 1, 0.00, null, false, 1),
	('basico', 'Basico', 10, 5, 5, 100.00, null, true, 2),
	('analista', 'Analista', 30, 10, 10, 300.00, null, true, 3),
	('personalizado', 'Personalizado', null, null, null, null, 10.00, true, 4)
on conflict (codigo) do nothing;

/******************************************************************************************
 * TABELA: audit.adm_planos
 */
create table audit.adm_planos (
	usuario_audit         varchar(50) default current_user not null,
	oper_audit            audit.enum_oper_audit default 'I' not null,
	dh_audit              timestamp(0) default current_timestamp not null,
	codigo                text not null,
	nome                  text not null,
	limite_contratacoes   integer null,
	limite_empresas       integer null,
	limite_usuarios       integer null,
	preco_mensal          numeric(12,2) null,
	preco_unitario        numeric(12,2) null,
	contratavel           boolean not null,
	ordem                 smallint not null
);

create index adm_planos_idx1 on audit.adm_planos (dh_audit, oper_audit, usuario_audit);
create index adm_planos_idx2 on audit.adm_planos (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_planos to sgisis;
grant select on audit.adm_planos to sgitec;
grant select on audit.adm_planos to consulta;

/******************************************************************************************
 * Criacao das triggers para audit
 */
create trigger audit_bi before insert on adm.planos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.planos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.planos for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.planos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.planos for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.assinaturas
 */
create table adm.assinaturas(
	created_by                     varchar(50) default current_user not null,
	created_at                     timestamp(0) default current_timestamp not null,
	updated_by                     varchar(50) default current_user not null,
	updated_at                     timestamp(0) default current_timestamp not null,
	deleted_by                     varchar(50) null,
	id                             serial,
	conta_id                       integer not null,
	plano_codigo                   text not null references adm.planos,
	limite_contratacoes            integer not null,
	limite_empresas                integer not null,
	limite_usuarios                integer not null,
	valor_mensal                   numeric(12,2) not null,
	dia_vencimento                 smallint not null,
	ciclo_inicio                   date not null,
	vigente_ate                    timestamptz not null,
	proximo_plano_codigo           text null references adm.planos,
	proximo_limite_contratacoes    integer null,
	proximo_limite_empresas        integer null,
	proximo_limite_usuarios        integer null,
	proximo_valor_mensal           numeric(12,2) null,
	constraint assinaturas_pkey primary key (id),
	constraint assinaturas_conta_id_fkey foreign key (conta_id) references adm.contas (id) on delete cascade,
	constraint assinaturas_dia_vencimento_chk check (dia_vencimento between 1 and 31),
	constraint assinaturas_conta_vigencia_ukey unique (conta_id, vigente_ate),
	constraint assinaturas_proximo_chk check (
		(proximo_plano_codigo is null and proximo_limite_contratacoes is null and proximo_limite_empresas is null and proximo_limite_usuarios is null and proximo_valor_mensal is null)
		or
		(proximo_plano_codigo is not null and proximo_limite_contratacoes is not null and proximo_limite_empresas is not null and proximo_limite_usuarios is not null and proximo_valor_mensal is not null)
	)
);

create index assinaturas_vigente_ate_idx on adm.assinaturas (vigente_ate);

grant select, insert, update on adm.assinaturas to sgisis;
grant select, insert, update on adm.assinaturas to sgitec;
grant select on adm.assinaturas to consulta;

/******************************************************************************************
 * TABELA: audit.adm_assinaturas
 */
create table audit.adm_assinaturas (
	usuario_audit                  varchar(50) default current_user not null,
	oper_audit                     audit.enum_oper_audit default 'I' not null,
	dh_audit                       timestamp(0) default current_timestamp not null,
	id                             integer not null,
	conta_id                       integer not null,
	plano_codigo                   text not null,
	limite_contratacoes            integer not null,
	limite_empresas                integer not null,
	limite_usuarios                integer not null,
	valor_mensal                   numeric(12,2) not null,
	dia_vencimento                 smallint not null,
	ciclo_inicio                   date not null,
	vigente_ate                    timestamptz not null,
	proximo_plano_codigo           text null,
	proximo_limite_contratacoes    integer null,
	proximo_limite_empresas        integer null,
	proximo_limite_usuarios        integer null,
	proximo_valor_mensal           numeric(12,2) null
);

create index adm_assinaturas_idx1 on audit.adm_assinaturas (dh_audit, oper_audit, usuario_audit);
create index adm_assinaturas_idx2 on audit.adm_assinaturas (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_assinaturas to sgisis;
grant select on audit.adm_assinaturas to sgitec;
grant select on audit.adm_assinaturas to consulta;

/******************************************************************************************
 * Criacao das triggers para audit
 */
create trigger audit_bi before insert on adm.assinaturas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.assinaturas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.assinaturas for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.assinaturas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.assinaturas for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.cobrancas
 */
create table adm.cobrancas(
	created_by            varchar(50) default current_user not null,
	created_at             timestamp(0) default current_timestamp not null,
	updated_by            varchar(50) default current_user not null,
	updated_at             timestamp(0) default current_timestamp not null,
	deleted_by            varchar(50) null,
	id                    serial,
	conta_id              integer not null references adm.contas,
	motivo                text not null,
	plano_codigo          text not null references adm.planos,
	limite_contratacoes   integer not null,
	limite_empresas       integer not null,
	limite_usuarios       integer not null,
	periodo_inicio        date not null,
	periodo_fim           date not null,
	valor                 numeric(12,2) not null,
	situacao              text not null,
	confirmada_em         timestamptz null,
	gateway_id            text null,
	constraint cobrancas_pkey primary key (id),
	constraint cobrancas_motivo_chk check (motivo in ('ciclo', 'upgrade_prorata', 'troca_vencimento_prorata')),
	constraint cobrancas_valor_chk check (valor >= 0),
	constraint cobrancas_situacao_chk check (situacao in ('confirmada_sem_gateway', 'pendente', 'paga', 'cancelada'))
);

create index cobrancas_conta_id_idx on adm.cobrancas (conta_id, id desc);

grant select, insert, update on adm.cobrancas to sgisis;
grant select, insert, update on adm.cobrancas to sgitec;
grant select on adm.cobrancas to consulta;

/******************************************************************************************
 * TABELA: audit.adm_cobrancas
 */
create table audit.adm_cobrancas (
	usuario_audit         varchar(50) default current_user not null,
	oper_audit            audit.enum_oper_audit default 'I' not null,
	dh_audit              timestamp(0) default current_timestamp not null,
	id                    integer not null,
	conta_id              integer not null,
	motivo                text not null,
	plano_codigo          text not null,
	limite_contratacoes   integer not null,
	limite_empresas       integer not null,
	limite_usuarios       integer not null,
	periodo_inicio        date not null,
	periodo_fim           date not null,
	valor                 numeric(12,2) not null,
	situacao              text not null,
	confirmada_em         timestamptz null,
	gateway_id            text null
);

create index adm_cobrancas_idx1 on audit.adm_cobrancas (dh_audit, oper_audit, usuario_audit);
create index adm_cobrancas_idx2 on audit.adm_cobrancas (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_cobrancas to sgisis;
grant select on audit.adm_cobrancas to sgitec;
grant select on audit.adm_cobrancas to consulta;

/******************************************************************************************
 * Criacao das triggers para audit
 */
create trigger audit_bi before insert on adm.cobrancas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.cobrancas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.cobrancas for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.cobrancas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.cobrancas for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.trials_concedidos
 */
create table adm.trials_concedidos(
	created_by      varchar(50) default current_user not null,
	created_at      timestamp(0) default current_timestamp not null,
	updated_by      varchar(50) default current_user not null,
	updated_at      timestamp(0) default current_timestamp not null,
	deleted_by      varchar(50) null,
	id              serial,
	conta_id        integer not null,
	documento       varchar(14) not null,
	email           text not null,
	usuario_login   varchar(50) not null,
	concedido_em    timestamptz default current_timestamp not null,
	constraint trials_concedidos_pkey primary key (id)
);

create index trials_concedidos_documento_idx on adm.trials_concedidos (documento);
create index trials_concedidos_email_idx on adm.trials_concedidos (email);
create index trials_concedidos_usuario_login_idx on adm.trials_concedidos (usuario_login);

grant select, insert, update on adm.trials_concedidos to sgisis;
grant select, insert, update on adm.trials_concedidos to sgitec;
grant select on adm.trials_concedidos to consulta;

/******************************************************************************************
 * TABELA: audit.adm_trials_concedidos
 */
create table audit.adm_trials_concedidos (
	usuario_audit   varchar(50) default current_user not null,
	oper_audit      audit.enum_oper_audit default 'I' not null,
	dh_audit        timestamp(0) default current_timestamp not null,
	id              integer not null,
	conta_id        integer not null,
	documento       varchar(14) not null,
	email           text not null,
	usuario_login   varchar(50) not null,
	concedido_em    timestamptz not null
);

create index adm_trials_concedidos_idx1 on audit.adm_trials_concedidos (dh_audit, oper_audit, usuario_audit);
create index adm_trials_concedidos_idx2 on audit.adm_trials_concedidos (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_trials_concedidos to sgisis;
grant select on audit.adm_trials_concedidos to sgitec;
grant select on audit.adm_trials_concedidos to consulta;

/******************************************************************************************
 * Criacao das triggers para audit
 */
create trigger audit_bi before insert on adm.trials_concedidos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.trials_concedidos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.trials_concedidos for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.trials_concedidos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.trials_concedidos for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.avisos_vencimento_enviados
 */
create table adm.avisos_vencimento_enviados(
	created_by     varchar(50) default current_user not null,
	created_at     timestamp(0) default current_timestamp not null,
	updated_by     varchar(50) default current_user not null,
	updated_at     timestamp(0) default current_timestamp not null,
	deleted_by     varchar(50) null,
	conta_id       integer not null,
	vigente_ate    timestamptz not null,
	tipo           text not null,
	enviado_em     timestamptz default current_timestamp not null,
	constraint avisos_vencimento_enviados_pkey primary key (conta_id, vigente_ate, tipo),
	constraint avisos_vencimento_enviados_conta_id_fkey foreign key (conta_id) references adm.contas (id) on delete cascade,
	constraint avisos_vencimento_enviados_tipo_chk check (tipo in ('5_dias', 'vencimento'))
);

grant select, insert, update on adm.avisos_vencimento_enviados to sgisis;
grant select, insert, update on adm.avisos_vencimento_enviados to sgitec;
grant select on adm.avisos_vencimento_enviados to consulta;

/******************************************************************************************
 * TABELA: audit.adm_avisos_vencimento_enviados
 */
create table audit.adm_avisos_vencimento_enviados (
	usuario_audit   varchar(50) default current_user not null,
	oper_audit      audit.enum_oper_audit default 'I' not null,
	dh_audit        timestamp(0) default current_timestamp not null,
	conta_id        integer not null,
	vigente_ate     timestamptz not null,
	tipo            text not null,
	enviado_em      timestamptz not null
);

create index adm_avisos_vencimento_enviados_idx1 on audit.adm_avisos_vencimento_enviados (dh_audit, oper_audit, usuario_audit);
create index adm_avisos_vencimento_enviados_idx2 on audit.adm_avisos_vencimento_enviados (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_avisos_vencimento_enviados to sgisis;
grant select on audit.adm_avisos_vencimento_enviados to sgitec;
grant select on audit.adm_avisos_vencimento_enviados to consulta;

/******************************************************************************************
 * Criacao das triggers para audit
 */
create trigger audit_bi before insert on adm.avisos_vencimento_enviados for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.avisos_vencimento_enviados for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.avisos_vencimento_enviados for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.avisos_vencimento_enviados for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.avisos_vencimento_enviados for each row execute function audit.func_audit_after();
