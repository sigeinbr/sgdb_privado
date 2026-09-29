/******************************************************************************************
 * Radar de Licitações — normalização de órgãos/unidades (pncp.orgaos / pncp.orgaos_unidades)
 *
 * pncp.contratacoes guarda órgão/unidade (e sub-rogados) como colunas de texto soltas desde
 * a denormalização feita em V202609181000 (commit a4c2645, "Tabela de contratações
 * denormalização"), para simplificar a sincronização manual via botão "Gravar". Agora que a
 * captura passa a gravar sozinha assim que a API do PNCP responde, volta a fazer sentido ter
 * órgão/unidade como catálogo com FK, evitando duplicar a mesma razão social em centenas de
 * linhas de contratações. Esta migration restaura pncp.orgaos/pncp.orgaos_unidades no mesmo
 * formato de V202608121000 (schema original), sem as colunas de texto redundantes que o
 * modelo antigo ainda mantinha em contratacoes.
 *
 * `cnpj_orgao` continua existindo em pncp.contratacoes (não é tocada aqui): além de
 * identificar o órgão, é parte da unique constraint de negócio
 * `contratacoes_ukey_cnpj_ano_sequencial` (cnpj_orgao, ano_compra, sequencial_compra).
 *
 * Esta migration só ADICIONA (tabelas e colunas novas, nullable) — não quebra o código atual,
 * que continua lendo/escrevendo as colunas de texto normalmente. Continua em duas migrations
 * seguintes, aplicadas no mesmo deploy (o pipeline builda e sobe a imagem Flyway a cada push
 * em main — não há uma janela manual separada esperando o deploy do backend):
 *   - V202609291100__pncp_orgaos_backfill.sql — popula o catálogo a partir das colunas de
 *     texto existentes e preenche os novos FKs em pncp.contratacoes.
 *   - V202609291200__pncp_orgaos_finalizar_normalizacao.sql — trava NOT NULL e derruba as
 *     colunas de texto antigas, que o backend deixa de usar a partir deste mesmo deploy.
 */

/******************************************************************************************
 * TABELA: pncp.orgaos
 */
create table pncp.orgaos(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial primary key,

	cnpj varchar(14) not null,
	razao_social text not null,
	poder_id varchar(1),      -- L=Legislativo, E=Executivo, J=Judiciário, N=Não se aplica
	esfera_id varchar(1),     -- F=Federal, E=Estadual, M=Municipal, D=Distrital, N=Não se aplica
	dados_json jsonb not null,
	ultima_sincronizacao_em timestamp(0) default current_timestamp not null,

	constraint orgaos_ukey unique(cnpj),
	constraint orgaos_cnpj_chk check (cnpj ~ '^[0-9]{14}$'),
	constraint orgaos_poder_id_chk check (poder_id is null or poder_id in ('L','E','J','N')),
	constraint orgaos_esfera_id_chk check (esfera_id is null or esfera_id in ('F','E','M','D','N'))
);
comment on table pncp.orgaos is
  'Órgão/entidade pública, conforme objeto orgaoEntidade (ou orgaoSubRogado) da API do PNCP. '
  'Tabela global — compartilhada entre todas as Contas, pois representa um cadastro público '
  '(CNPJ) que não varia por Conta.';

grant select, insert, update, delete on pncp.orgaos to sgisis;
grant select, insert, update, delete on pncp.orgaos to sgitec;
grant select on pncp.orgaos to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_orgaos_dados_json on pncp.orgaos using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_orgaos
 */
create table audit.pncp_orgaos (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,

	cnpj varchar(14) not null,
	razao_social text not null,
	poder_id varchar(1),
	esfera_id varchar(1),
	dados_json jsonb not null,
	ultima_sincronizacao_em timestamp(0) not null
);

create index pncp_orgaos_idx1 on audit.pncp_orgaos(dh_audit,oper_audit,usuario_audit);
create index pncp_orgaos_idx2 on audit.pncp_orgaos(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_orgaos to sgisis;
grant select on audit.pncp_orgaos to sgitec;
grant select on audit.pncp_orgaos to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.orgaos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.orgaos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.orgaos for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.orgaos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.orgaos for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.orgaos_unidades
 *
 * orgao_id usa ON DELETE CASCADE (diferente do restrict original de V202608121000) — decisão
 * deliberada do pedido de manutenção: excluir um órgão do catálogo deve arrastar suas
 * unidades, que não fazem sentido órfãs.
 */
create table pncp.orgaos_unidades(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial primary key,

	orgao_id integer not null references pncp.orgaos(id) on delete cascade,
	codigo_unidade varchar(20) not null,
	nome_unidade text,
	uf_sigla varchar(2),
	uf_nome text,
	municipio_nome text,
	codigo_ibge varchar(10),
	dados_json jsonb not null,

	constraint orgaos_unidades_ukey unique(orgao_id, codigo_unidade)
);
comment on table pncp.orgaos_unidades is
  'Unidade administrativa de um órgão, conforme objeto unidadeOrgao (ou unidadeSubRogada) da API '
  'do PNCP. Tabela global, no mesmo padrão de pncp.orgaos.';

grant select, insert, update, delete on pncp.orgaos_unidades to sgisis;
grant select, insert, update, delete on pncp.orgaos_unidades to sgitec;
grant select on pncp.orgaos_unidades to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_orgaos_unidades_orgao_id on pncp.orgaos_unidades (orgao_id);
create index ix_orgaos_unidades_uf_sigla on pncp.orgaos_unidades (uf_sigla);
create index ix_orgaos_unidades_dados_json on pncp.orgaos_unidades using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_orgaos_unidades
 */
create table audit.pncp_orgaos_unidades (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,

	orgao_id integer not null,
	codigo_unidade varchar(20) not null,
	nome_unidade text,
	uf_sigla varchar(2),
	uf_nome text,
	municipio_nome text,
	codigo_ibge varchar(10),
	dados_json jsonb not null
);

create index pncp_orgaos_unidades_idx1 on audit.pncp_orgaos_unidades(dh_audit,oper_audit,usuario_audit);
create index pncp_orgaos_unidades_idx2 on audit.pncp_orgaos_unidades(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_orgaos_unidades to sgisis;
grant select on audit.pncp_orgaos_unidades to sgitec;
grant select on audit.pncp_orgaos_unidades to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.orgaos_unidades for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.orgaos_unidades for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.orgaos_unidades for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.orgaos_unidades for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.orgaos_unidades for each row execute function audit.func_audit_after();

/******************************************************************************************
 * pncp.contratacoes / audit.pncp_contratacoes — novas colunas de FK, nullable por enquanto.
 *
 * Viram NOT NULL (as obrigatórias: orgao_entidade_id/unidade_orgao_id) em
 * ajustes_pontuais_pncp_orgaos_finalizar_normalizacao.sql, depois que o backfill de
 * ajustes_pontuais_pncp_orgaos_backfill.sql preencher 100% das linhas existentes.
 * Sub-rogado fica sempre nullable, como já é hoje nas colunas de texto.
 */
alter table pncp.contratacoes
	add column orgao_entidade_id integer null,
	add column unidade_orgao_id integer null,
	add column orgao_subrogado_id integer null,
	add column unidade_subrogada_id integer null;

alter table audit.pncp_contratacoes
	add column orgao_entidade_id integer,
	add column unidade_orgao_id integer,
	add column orgao_subrogado_id integer,
	add column unidade_subrogada_id integer;

alter table pncp.contratacoes
	add constraint contratacoes_fkey_orgao_entidade
	foreign key (orgao_entidade_id) references pncp.orgaos(id) on delete restrict;
alter table pncp.contratacoes
	add constraint contratacoes_fkey_unidade_orgao
	foreign key (unidade_orgao_id) references pncp.orgaos_unidades(id) on delete restrict;
alter table pncp.contratacoes
	add constraint contratacoes_fkey_orgao_subrogado
	foreign key (orgao_subrogado_id) references pncp.orgaos(id) on delete restrict;
alter table pncp.contratacoes
	add constraint contratacoes_fkey_unidade_subrogada
	foreign key (unidade_subrogada_id) references pncp.orgaos_unidades(id) on delete restrict;

create index ix_contratacoes_orgao_entidade on pncp.contratacoes (orgao_entidade_id);
create index ix_contratacoes_unidade_orgao on pncp.contratacoes (unidade_orgao_id);
create index ix_contratacoes_orgao_subrogado on pncp.contratacoes (orgao_subrogado_id) where orgao_subrogado_id is not null;
