/******************************************************************************************
 * TABELA: pncp.contratacoes_mensagens_mencoes
 *
 * Um sinal por mensagem indicando que ela provavelmente é destinada à conta: bateu por
 * destinatário explícito (identificador_destinatario), por CNPJ da conta no texto, ou pelo
 * nome/razão social da conta no texto. Quando mais de um sinal bate na mesma mensagem, o
 * job grava só o mais forte (destinatario > cnpj_texto > nome_texto) — por isso a PK é
 * (conta_id, mensagem_id), não (conta_id, mensagem_id, tipo_sinal). contratacao_id e
 * data_hora_mensagem são denormalizados de pncp.contratacoes_mensagens para o dashboard
 * não precisar de join; email_enviado_em marca quando o digest saiu (nulo = pendente).
 */
create table pncp.contratacoes_mensagens_mencoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null,
	mensagem_id integer not null,

	contratacao_id integer not null,
	tipo_sinal varchar(15) not null,
	trecho text not null,
	data_hora_mensagem timestamp(0) not null,
	detectado_em timestamp(0) not null,
	email_enviado_em timestamp(0) null,

	constraint contratacoes_mensagens_mencoes_pkey primary key (conta_id, mensagem_id),
	constraint contratacoes_mensagens_mencoes_conta_id_fkey foreign key (conta_id) references adm.contas (id),
	constraint contratacoes_mensagens_mencoes_mensagem_id_fkey foreign key (mensagem_id) references pncp.contratacoes_mensagens (id) on delete cascade,
	constraint contratacoes_mensagens_mencoes_contratacao_id_fkey foreign key (contratacao_id) references pncp.contratacoes (id) on delete cascade,
	constraint contratacoes_mensagens_mencoes_tipo_sinal_chk check (tipo_sinal in ('destinatario','cnpj_texto','nome_texto'))
);
comment on table pncp.contratacoes_mensagens_mencoes is
  'Sinal (o mais forte, quando mais de um bate) de que uma mensagem é destinada à conta: '
  'por destinatário explícito, CNPJ no texto ou nome/razão social no texto.';
comment on column pncp.contratacoes_mensagens_mencoes.contratacao_id is 'denormalizado de contratacoes_mensagens, evita join no dashboard';
comment on column pncp.contratacoes_mensagens_mencoes.data_hora_mensagem is 'denormalizado de contratacoes_mensagens, usado no filtro de faixa do dashboard';
comment on column pncp.contratacoes_mensagens_mencoes.email_enviado_em is 'nulo até o digest sair';

grant select, insert, update, delete on pncp.contratacoes_mensagens_mencoes to sgisis;
grant select, insert, update, delete on pncp.contratacoes_mensagens_mencoes to sgitec;
grant select on pncp.contratacoes_mensagens_mencoes to consulta;

create index ix_contratacoes_mensagens_mencoes_contratacao_id on pncp.contratacoes_mensagens_mencoes (contratacao_id);
create index ix_contratacoes_mensagens_mencoes_conta_data on pncp.contratacoes_mensagens_mencoes (conta_id, data_hora_mensagem desc);
create index ix_contratacoes_mensagens_mencoes_pendentes on pncp.contratacoes_mensagens_mencoes (conta_id, data_hora_mensagem) where email_enviado_em is null;

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes_mensagens_mencoes
 */
create table audit.pncp_contratacoes_mensagens_mencoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	mensagem_id integer not null,

	contratacao_id integer not null,
	tipo_sinal varchar(15) not null,
	trecho text not null,
	data_hora_mensagem timestamp(0) not null,
	detectado_em timestamp(0) not null,
	email_enviado_em timestamp(0)
);

create index pncp_contratacoes_mensagens_mencoes_idx1 on audit.pncp_contratacoes_mensagens_mencoes(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_mensagens_mencoes_idx2 on audit.pncp_contratacoes_mensagens_mencoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_mensagens_mencoes to sgisis;
grant select on audit.pncp_contratacoes_mensagens_mencoes to sgitec;
grant select on audit.pncp_contratacoes_mensagens_mencoes to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes_mensagens_mencoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_mensagens_mencoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_mensagens_mencoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_mensagens_mencoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_mensagens_mencoes for each row execute function audit.func_audit_after();
