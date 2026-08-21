/******************************************************************************************
 * TABELA: pncp.contratacoes_mensagens
 *
 * Filha de pncp.contratacoes (via contratacao_id). Mensagens trocadas durante o certame
 * (convocações, comunicações do pregoeiro, mensagens de fornecedores), endpoint
 * .../mensagens da API do PNCP. O chaveCompra desse endpoint usa esquema baseado em UASG
 * (numeroUasg/idModalidade/numero/ano), diferente do numero_controle_pncp usado em
 * pncp.contratacoes — por isso não é armazenado em colunas próprias aqui: a aplicação
 * resolve contratacao_id antes do insert, no mesmo padrão das demais filhas de
 * pncp.contratacoes, e o payload bruto (incluindo o chaveCompra original) fica preservado
 * em dados_json.
 */
create table pncp.contratacoes_mensagens(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	contratacao_id integer not null,
	numero_item integer,                    -- API: identificadorItem (nulo quando a mensagem não é de um item específico)
	chave_mensagem_origem varchar(60) not null,  -- API: chaveMensagemNaOrigem (UUID)
	texto text not null,
	categoria smallint,                     -- código de domínio do PNCP para o tipo da mensagem (API: categoria)
	data_hora timestamp(0) not null,        -- API: dataHora
	tipo_remetente varchar(1),              -- '0'=órgão/pregoeiro, '1'=fornecedor (API: tipoRemetente)
	identificador_remetente varchar(20),    -- CNPJ/CPF de quem enviou (API: identificadorRemetente)
	identificador_destinatario varchar(20), -- CNPJ/CPF de quem recebeu (API: identificadorDestinatario)
	dados_json jsonb not null,

	constraint contratacoes_mensagens_pkey primary key (id),
	constraint contratacoes_mensagens_ukey unique (conta_id, chave_mensagem_origem),
	constraint contratacoes_mensagens_tipo_remetente_chk check (tipo_remetente is null or tipo_remetente in ('0','1')),
	foreign key (contratacao_id) references pncp.contratacoes(id) on delete cascade,
	foreign key (contratacao_id, numero_item) references pncp.contratacoes_itens(contratacao_id, numero_item) on delete cascade
);
comment on table pncp.contratacoes_mensagens is
  'Mensagens trocadas durante o certame (convocações, comunicações do pregoeiro, mensagens '
  'de fornecedores), endpoint .../mensagens da API do PNCP. chaveCompra (UASG-based) não é '
  'armazenado em colunas próprias — a aplicação resolve contratacao_id antes do insert, no '
  'mesmo padrão das demais filhas de pncp.contratacoes; o payload bruto, incluindo o '
  'chaveCompra original, fica preservado em dados_json.';

grant select, insert, update, delete on pncp.contratacoes_mensagens to sgisis;
grant select, insert, update, delete on pncp.contratacoes_mensagens to sgitec;
grant select on pncp.contratacoes_mensagens to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_mensagens_conta_id on pncp.contratacoes_mensagens (conta_id);
create index ix_contratacoes_mensagens_contratacao_id on pncp.contratacoes_mensagens (contratacao_id);
create index ix_contratacoes_mensagens_data_hora on pncp.contratacoes_mensagens (data_hora);
create index ix_contratacoes_mensagens_categoria on pncp.contratacoes_mensagens (categoria);
create index ix_contratacoes_mensagens_dados_json on pncp.contratacoes_mensagens using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes_mensagens
 */
create table audit.pncp_contratacoes_mensagens (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,

	contratacao_id integer not null,
	numero_item integer,
	chave_mensagem_origem varchar(60) not null,
	texto text not null,
	categoria smallint,
	data_hora timestamp(0) not null,
	tipo_remetente varchar(1),
	identificador_remetente varchar(20),
	identificador_destinatario varchar(20),
	dados_json jsonb not null
);

create index pncp_contratacoes_mensagens_idx1 on audit.pncp_contratacoes_mensagens(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_mensagens_idx2 on audit.pncp_contratacoes_mensagens(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_mensagens to sgisis;
grant select on audit.pncp_contratacoes_mensagens to sgitec;
grant select on audit.pncp_contratacoes_mensagens to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes_mensagens for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_mensagens for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_mensagens for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_mensagens for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_mensagens for each row execute function audit.func_audit_after();
