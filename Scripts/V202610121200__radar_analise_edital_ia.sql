/******************************************************************************************
 * Radar de Licitações - análise de edital com IA (Bloco único, antes do deploy)
 *
 * - radar.analise_edital_config: linha única (id = 1) com modelo, prompt e limites; ajustada
 *   por UPDATE direto, vale na próxima análise sem deploy
 * - radar.analises_edital: uma análise por contratação, compartilhada entre as contas
 * - radar.analises_edital_solicitacoes: registro de cada pedido (base para cota/cobrança)
 *
 * Aditivo: o código antigo não lê as tabelas. Sem a linha de configuração, toda análise
 * falha com "recurso indisponível" - por isso a carga está nesta mesma migration.
 */

/******************************************************************************************
 * TABELA: radar.analise_edital_config
 */
create table radar.analise_edital_config(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id smallint not null,
	modelo varchar(100) not null,
	prompt text not null,
	max_tokens_saida integer not null,
	limite_caracteres_entrada integer not null,

	constraint analise_edital_config_pkey primary key (id),
	constraint analise_edital_config_id_chk check (id = 1),
	constraint analise_edital_config_max_tokens_saida_chk check (max_tokens_saida > 0),
	constraint analise_edital_config_limite_caracteres_entrada_chk check (limite_caracteres_entrada > 0)
);
comment on table radar.analise_edital_config is
  'Configuração global da análise de edital por IA: linha única (id = 1). Ajuste por UPDATE.';

grant select, insert, update, delete on radar.analise_edital_config to sgisis;
grant select, insert, update, delete on radar.analise_edital_config to sgitec;
grant select on radar.analise_edital_config to consulta;

/******************************************************************************************
 * TABELA: audit.radar_analise_edital_config
 */
create table audit.radar_analise_edital_config (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id smallint not null,
	modelo varchar(100) not null,
	prompt text not null,
	max_tokens_saida integer not null,
	limite_caracteres_entrada integer not null
);

create index radar_analise_edital_config_idx1 on audit.radar_analise_edital_config(dh_audit,oper_audit,usuario_audit);
create index radar_analise_edital_config_idx2 on audit.radar_analise_edital_config(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.radar_analise_edital_config to sgisis;
grant select on audit.radar_analise_edital_config to sgitec;
grant select on audit.radar_analise_edital_config to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on radar.analise_edital_config for each row execute function audit.func_audit_before();
create trigger audit_bu before update on radar.analise_edital_config for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on radar.analise_edital_config for each row execute function audit.func_audit_after();
create trigger audit_au after update on radar.analise_edital_config for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on radar.analise_edital_config for each row execute function audit.func_audit_after();

/******************************************************************************************
 * Carga: prompt = texto do apêndice A da spec de análise de edital, sem alteração
 */
insert into radar.analise_edital_config (id, modelo, prompt, max_tokens_saida, limite_caracteres_entrada)
values (1, 'gpt-4.1-mini', $prompt$Você é um especialista em licitações públicas brasileiras (Lei 14.133/2021) e analisa
documentos de uma contratação publicada no PNCP para uma empresa licitante.

O texto dos documentos vem marcado com [Documento: <título> | pág. <n>]. Use somente o que
está nos documentos. Para cada informação, cite a fonte entre parênteses no formato
(<título>, pág. <n>). Quando algo não constar nos documentos, escreva "Não informado nos
documentos". Nunca presuma valores, datas ou exigências.

Responda em português do Brasil, em Markdown, exatamente com esta estrutura:

## Triagem
- **Objeto:** uma frase.
- **Modalidade / critério de julgamento / modo de disputa:**
- **Valor estimado:** (ou "sigiloso")
- **Datas-chave:** abertura das propostas, sessão pública, prazo de esclarecimentos e de
  impugnação.
- **Participação:** exclusiva ME/EPP, cota reservada ou ampla.
- **Pontos de atenção:** até 5 itens com riscos ou exigências incomuns.

## 1. Habilitação jurídica, fiscal e trabalhista
## 2. Qualificação técnica
Atestados, quantitativos mínimos, visita técnica, registros em conselho.
## 3. Qualificação econômico-financeira
Índices, capital ou patrimônio líquido mínimo, certidões.
## 4. Proposta
Formato, amostras, validade, planilha de custos, documentos que acompanham.
## 5. Execução
Prazo e local de entrega ou execução, vigência, condições de pagamento.
## 6. Garantias e penalidades
## 7. Itens e lotes relevantes
Resumo dos itens/lotes de maior valor ou com exigências específicas.$prompt$, 8000, 1500000);

/******************************************************************************************
 * TABELA: radar.analises_edital
 */
create table radar.analises_edital(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial,
	numero_controle_pncp varchar not null,
	status varchar(12) not null,
	conteudo text null,
	documentos jsonb null,
	modelo varchar(100) null,
	tokens_entrada integer null,
	tokens_saida integer null,
	erro text null,
	iniciada_em timestamptz not null,
	concluida_em timestamptz null,

	constraint analises_edital_pkey primary key (id),
	constraint analises_edital_numero_controle_pncp_ukey unique (numero_controle_pncp),
	constraint analises_edital_status_chk check (status in ('processando', 'concluida', 'erro'))
);
comment on table radar.analises_edital is
  'Análise por IA dos documentos de uma contratação: única por contratação e compartilhada entre as contas. Para refazer, excluir pelo padrão (deleted_by).';
comment on column radar.analises_edital.conteudo is 'Markdown gerado';

-- job de recuperação varre só as análises em andamento
create index analises_edital_processando_idx on radar.analises_edital(iniciada_em) where status = 'processando';

grant select, insert, update, delete on radar.analises_edital to sgisis;
grant select, insert, update, delete on radar.analises_edital to sgitec;
grant select on radar.analises_edital to consulta;

/******************************************************************************************
 * TABELA: audit.radar_analises_edital
 */
create table audit.radar_analises_edital (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	numero_controle_pncp varchar not null,
	status varchar(12) not null,
	conteudo text,
	documentos jsonb,
	modelo varchar(100),
	tokens_entrada integer,
	tokens_saida integer,
	erro text,
	iniciada_em timestamptz not null,
	concluida_em timestamptz
);

create index radar_analises_edital_idx1 on audit.radar_analises_edital(dh_audit,oper_audit,usuario_audit);
create index radar_analises_edital_idx2 on audit.radar_analises_edital(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.radar_analises_edital to sgisis;
grant select on audit.radar_analises_edital to sgitec;
grant select on audit.radar_analises_edital to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on radar.analises_edital for each row execute function audit.func_audit_before();
create trigger audit_bu before update on radar.analises_edital for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on radar.analises_edital for each row execute function audit.func_audit_after();
create trigger audit_au after update on radar.analises_edital for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on radar.analises_edital for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: radar.analises_edital_solicitacoes
 *
 * conta_id sem ação em cascata: é histórico de uso (cota/cobrança) e conta não é excluída
 * fisicamente. A FK composta (empresa_id, conta_id) garante que a empresa pertence à conta.
 */
create table radar.analises_edital_solicitacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial,
	analise_id integer not null,
	conta_id integer not null,
	empresa_id integer not null,
	usuario_login varchar(50) not null,
	origem varchar(10) not null,

	constraint analises_edital_solicitacoes_pkey primary key (id),
	constraint analises_edital_solicitacoes_analise_id_fkey foreign key (analise_id) references radar.analises_edital(id) on delete cascade,
	constraint analises_edital_solicitacoes_conta_id_fkey foreign key (conta_id) references adm.contas(id),
	constraint analises_edital_solicitacoes_empresa_conta_fkey foreign key (empresa_id, conta_id) references radar.empresas(id, conta_id) on delete cascade,
	constraint analises_edital_solicitacoes_origem_chk check (origem in ('pesquisa', 'boletim'))
);
comment on table radar.analises_edital_solicitacoes is
  'Cada pedido de análise de edital (pesquisa ou boletim): histórico de uso, base para cota/cobrança.';

-- base para cota/cobrança por conta
create index analises_edital_solicitacoes_conta_created_idx on radar.analises_edital_solicitacoes(conta_id, created_at);
-- FKs com delete em cascata precisam de índice no lado filho
create index analises_edital_solicitacoes_analise_id_idx on radar.analises_edital_solicitacoes(analise_id);
create index analises_edital_solicitacoes_empresa_conta_idx on radar.analises_edital_solicitacoes(empresa_id, conta_id);

grant select, insert, update, delete on radar.analises_edital_solicitacoes to sgisis;
grant select, insert, update, delete on radar.analises_edital_solicitacoes to sgitec;
grant select on radar.analises_edital_solicitacoes to consulta;

/******************************************************************************************
 * TABELA: audit.radar_analises_edital_solicitacoes
 */
create table audit.radar_analises_edital_solicitacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	analise_id integer not null,
	conta_id integer not null,
	empresa_id integer not null,
	usuario_login varchar(50) not null,
	origem varchar(10) not null
);

create index radar_analises_edital_solicitacoes_idx1 on audit.radar_analises_edital_solicitacoes(dh_audit,oper_audit,usuario_audit);
create index radar_analises_edital_solicitacoes_idx2 on audit.radar_analises_edital_solicitacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.radar_analises_edital_solicitacoes to sgisis;
grant select on audit.radar_analises_edital_solicitacoes to sgitec;
grant select on audit.radar_analises_edital_solicitacoes to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on radar.analises_edital_solicitacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on radar.analises_edital_solicitacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on radar.analises_edital_solicitacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update on radar.analises_edital_solicitacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on radar.analises_edital_solicitacoes for each row execute function audit.func_audit_after();
