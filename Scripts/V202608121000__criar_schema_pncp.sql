/******************************************************************************************
 * SCHEMA: pncp — espelhamento/ingestão de dados brutos da API do PNCP
 */
create schema pncp;

comment on schema pncp is
  'Camada de espelhamento (ingestão) dos dados públicos da API do PNCP. '
  'Não contém regras de negócio do módulo Disputa — apenas réplica normalizada '
  'do que a API devolve, preservando o payload bruto por granularidade em colunas jsonb.';

grant usage on schema pncp to sgisis;
grant usage on schema pncp to sgitec;
grant usage on schema pncp to consulta;

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
	poder_id varchar(1),      -- L=Legislativo, E=Executivo, J=Judiciário
	esfera_id varchar(1),     -- F=Federal, E=Estadual, M=Municipal, D=Distrital
	dados_json jsonb not null,
	ultima_sincronizacao_em timestamp(0) default current_timestamp not null,

	constraint orgaos_ukey unique(cnpj),
	constraint orgaos_cnpj_chk check (cnpj ~ '^[0-9]{14}$'),
	constraint orgaos_poder_id_chk check (poder_id is null or poder_id in ('L','E','J')),
	constraint orgaos_esfera_id_chk check (esfera_id is null or esfera_id in ('F','E','M','D'))
);
comment on table pncp.orgaos is
  'Órgão/entidade pública, conforme objeto orgaoEntidade (ou orgaoSubRogado) da API do PNCP. '
  'Tabela global — compartilhada entre todas as Unidades Gestoras, pois representa um cadastro '
  'público (CNPJ) que não varia por UG.';

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
 */
create table pncp.orgaos_unidades(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id serial primary key,

	orgao_id integer not null references pncp.orgaos(id) on delete restrict,
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
 * TABELAS DE DOMÍNIO (listas fixas do PNCP)
 *
 * Todas globais (sem conta_id), id fornecido pela própria API (não gerado pelo banco),
 * sem seed nesta migration — nascem vazias e são populadas via
 * "insert ... on conflict (id) do update" pela rotina de sincronização, sempre que
 * ela encontrar um par id/nome novo retornado pela API. As triggers de auditoria
 * padrão já cobrem esse upsert corretamente (insert vira 'I', update de nome vira 'A').
 */

/******************************************************************************************
 * TABELA: pncp.modalidades_contratacao
 */
create table pncp.modalidades_contratacao(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.modalidades_contratacao is
  'Domínio do PNCP para modalidade de contratação (modalidadeId/modalidadeNome).';

grant select, insert, update, delete on pncp.modalidades_contratacao to sgisis;
grant select, insert, update, delete on pncp.modalidades_contratacao to sgitec;
grant select on pncp.modalidades_contratacao to consulta;

create table audit.pncp_modalidades_contratacao (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_modalidades_contratacao_idx1 on audit.pncp_modalidades_contratacao(dh_audit,oper_audit,usuario_audit);
create index pncp_modalidades_contratacao_idx2 on audit.pncp_modalidades_contratacao(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_modalidades_contratacao to sgisis;
grant select on audit.pncp_modalidades_contratacao to sgitec;
grant select on audit.pncp_modalidades_contratacao to consulta;

create trigger audit_bi before insert on pncp.modalidades_contratacao for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.modalidades_contratacao for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.modalidades_contratacao for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.modalidades_contratacao for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.modalidades_contratacao for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.modos_disputa
 */
create table pncp.modos_disputa(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.modos_disputa is
  'Domínio do PNCP para modo de disputa (modoDisputaId/modoDisputaNome).';

grant select, insert, update, delete on pncp.modos_disputa to sgisis;
grant select, insert, update, delete on pncp.modos_disputa to sgitec;
grant select on pncp.modos_disputa to consulta;

create table audit.pncp_modos_disputa (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_modos_disputa_idx1 on audit.pncp_modos_disputa(dh_audit,oper_audit,usuario_audit);
create index pncp_modos_disputa_idx2 on audit.pncp_modos_disputa(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_modos_disputa to sgisis;
grant select on audit.pncp_modos_disputa to sgitec;
grant select on audit.pncp_modos_disputa to consulta;

create trigger audit_bi before insert on pncp.modos_disputa for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.modos_disputa for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.modos_disputa for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.modos_disputa for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.modos_disputa for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.tipos_instrumentos_convocatorios
 */
create table pncp.tipos_instrumentos_convocatorios(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.tipos_instrumentos_convocatorios is
  'Domínio do PNCP para tipo de instrumento convocatório (tipoInstrumentoConvocatorio.codigo/nome).';

grant select, insert, update, delete on pncp.tipos_instrumentos_convocatorios to sgisis;
grant select, insert, update, delete on pncp.tipos_instrumentos_convocatorios to sgitec;
grant select on pncp.tipos_instrumentos_convocatorios to consulta;

create table audit.pncp_tipos_instrumentos_convocatorios (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_tipos_instrumentos_convocatorios_idx1 on audit.pncp_tipos_instrumentos_convocatorios(dh_audit,oper_audit,usuario_audit);
create index pncp_tipos_instrumentos_convocatorios_idx2 on audit.pncp_tipos_instrumentos_convocatorios(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_tipos_instrumentos_convocatorios to sgisis;
grant select on audit.pncp_tipos_instrumentos_convocatorios to sgitec;
grant select on audit.pncp_tipos_instrumentos_convocatorios to consulta;

create trigger audit_bi before insert on pncp.tipos_instrumentos_convocatorios for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.tipos_instrumentos_convocatorios for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.tipos_instrumentos_convocatorios for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.tipos_instrumentos_convocatorios for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.tipos_instrumentos_convocatorios for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.amparos_legais
 */
create table pncp.amparos_legais(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null,
	descricao text
);
comment on table pncp.amparos_legais is
  'Domínio do PNCP para amparo legal (amparoLegal.codigo/nome/descricao).';

grant select, insert, update, delete on pncp.amparos_legais to sgisis;
grant select, insert, update, delete on pncp.amparos_legais to sgitec;
grant select on pncp.amparos_legais to consulta;

create table audit.pncp_amparos_legais (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null,
	descricao text
);

create index pncp_amparos_legais_idx1 on audit.pncp_amparos_legais(dh_audit,oper_audit,usuario_audit);
create index pncp_amparos_legais_idx2 on audit.pncp_amparos_legais(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_amparos_legais to sgisis;
grant select on audit.pncp_amparos_legais to sgitec;
grant select on audit.pncp_amparos_legais to consulta;

create trigger audit_bi before insert on pncp.amparos_legais for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.amparos_legais for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.amparos_legais for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.amparos_legais for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.amparos_legais for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.situacoes_compra
 */
create table pncp.situacoes_compra(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.situacoes_compra is
  'Domínio do PNCP para situação da compra (situacaoCompraId/situacaoCompraNome). '
  'Usada tanto pela contratação atual (pncp.contratacoes) quanto pelo histórico '
  '(pncp.contratacoes_situacoes).';

grant select, insert, update, delete on pncp.situacoes_compra to sgisis;
grant select, insert, update, delete on pncp.situacoes_compra to sgitec;
grant select on pncp.situacoes_compra to consulta;

create table audit.pncp_situacoes_compra (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_situacoes_compra_idx1 on audit.pncp_situacoes_compra(dh_audit,oper_audit,usuario_audit);
create index pncp_situacoes_compra_idx2 on audit.pncp_situacoes_compra(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_situacoes_compra to sgisis;
grant select on audit.pncp_situacoes_compra to sgitec;
grant select on audit.pncp_situacoes_compra to consulta;

create trigger audit_bi before insert on pncp.situacoes_compra for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.situacoes_compra for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.situacoes_compra for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.situacoes_compra for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.situacoes_compra for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.tipos_orcamento_sigiloso
 */
create table pncp.tipos_orcamento_sigiloso(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.tipos_orcamento_sigiloso is
  'Domínio do PNCP para orçamento sigiloso da contratação (orcamentoSigilosoCodigo/Descricao).';

grant select, insert, update, delete on pncp.tipos_orcamento_sigiloso to sgisis;
grant select, insert, update, delete on pncp.tipos_orcamento_sigiloso to sgitec;
grant select on pncp.tipos_orcamento_sigiloso to consulta;

create table audit.pncp_tipos_orcamento_sigiloso (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_tipos_orcamento_sigiloso_idx1 on audit.pncp_tipos_orcamento_sigiloso(dh_audit,oper_audit,usuario_audit);
create index pncp_tipos_orcamento_sigiloso_idx2 on audit.pncp_tipos_orcamento_sigiloso(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_tipos_orcamento_sigiloso to sgisis;
grant select on audit.pncp_tipos_orcamento_sigiloso to sgitec;
grant select on audit.pncp_tipos_orcamento_sigiloso to consulta;

create trigger audit_bi before insert on pncp.tipos_orcamento_sigiloso for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.tipos_orcamento_sigiloso for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.tipos_orcamento_sigiloso for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.tipos_orcamento_sigiloso for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.tipos_orcamento_sigiloso for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.categorias_itens
 */
create table pncp.categorias_itens(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.categorias_itens is
  'Domínio do PNCP para categoria do item da contratação (itemCategoriaId/itemCategoriaNome).';

grant select, insert, update, delete on pncp.categorias_itens to sgisis;
grant select, insert, update, delete on pncp.categorias_itens to sgitec;
grant select on pncp.categorias_itens to consulta;

create table audit.pncp_categorias_itens (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_categorias_itens_idx1 on audit.pncp_categorias_itens(dh_audit,oper_audit,usuario_audit);
create index pncp_categorias_itens_idx2 on audit.pncp_categorias_itens(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_categorias_itens to sgisis;
grant select on audit.pncp_categorias_itens to sgitec;
grant select on audit.pncp_categorias_itens to consulta;

create trigger audit_bi before insert on pncp.categorias_itens for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.categorias_itens for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.categorias_itens for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.categorias_itens for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.categorias_itens for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.criterios_julgamento
 */
create table pncp.criterios_julgamento(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.criterios_julgamento is
  'Domínio do PNCP para critério de julgamento do item (criterioJulgamentoId/criterioJulgamentoNome).';

grant select, insert, update, delete on pncp.criterios_julgamento to sgisis;
grant select, insert, update, delete on pncp.criterios_julgamento to sgitec;
grant select on pncp.criterios_julgamento to consulta;

create table audit.pncp_criterios_julgamento (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_criterios_julgamento_idx1 on audit.pncp_criterios_julgamento(dh_audit,oper_audit,usuario_audit);
create index pncp_criterios_julgamento_idx2 on audit.pncp_criterios_julgamento(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_criterios_julgamento to sgisis;
grant select on audit.pncp_criterios_julgamento to sgitec;
grant select on audit.pncp_criterios_julgamento to consulta;

create trigger audit_bi before insert on pncp.criterios_julgamento for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.criterios_julgamento for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.criterios_julgamento for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.criterios_julgamento for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.criterios_julgamento for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.tipos_beneficios
 */
create table pncp.tipos_beneficios(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.tipos_beneficios is
  'Domínio do PNCP para tipo de benefício do item (tipoBeneficioId/tipoBeneficioNome).';

grant select, insert, update, delete on pncp.tipos_beneficios to sgisis;
grant select, insert, update, delete on pncp.tipos_beneficios to sgitec;
grant select on pncp.tipos_beneficios to consulta;

create table audit.pncp_tipos_beneficios (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_tipos_beneficios_idx1 on audit.pncp_tipos_beneficios(dh_audit,oper_audit,usuario_audit);
create index pncp_tipos_beneficios_idx2 on audit.pncp_tipos_beneficios(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_tipos_beneficios to sgisis;
grant select on audit.pncp_tipos_beneficios to sgitec;
grant select on audit.pncp_tipos_beneficios to consulta;

create trigger audit_bi before insert on pncp.tipos_beneficios for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.tipos_beneficios for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.tipos_beneficios for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.tipos_beneficios for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.tipos_beneficios for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.situacoes_item
 */
create table pncp.situacoes_item(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.situacoes_item is
  'Domínio do PNCP para situação do item da compra (situacaoCompraItem/situacaoCompraItemNome).';

grant select, insert, update, delete on pncp.situacoes_item to sgisis;
grant select, insert, update, delete on pncp.situacoes_item to sgitec;
grant select on pncp.situacoes_item to consulta;

create table audit.pncp_situacoes_item (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_situacoes_item_idx1 on audit.pncp_situacoes_item(dh_audit,oper_audit,usuario_audit);
create index pncp_situacoes_item_idx2 on audit.pncp_situacoes_item(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_situacoes_item to sgisis;
grant select on audit.pncp_situacoes_item to sgitec;
grant select on audit.pncp_situacoes_item to consulta;

create trigger audit_bi before insert on pncp.situacoes_item for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.situacoes_item for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.situacoes_item for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.situacoes_item for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.situacoes_item for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.situacoes_resultado_item
 */
create table pncp.situacoes_resultado_item(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null
);
comment on table pncp.situacoes_resultado_item is
  'Domínio do PNCP para situação do resultado do item (situacaoCompraItemResultadoId/Nome).';

grant select, insert, update, delete on pncp.situacoes_resultado_item to sgisis;
grant select, insert, update, delete on pncp.situacoes_resultado_item to sgitec;
grant select on pncp.situacoes_resultado_item to consulta;

create table audit.pncp_situacoes_resultado_item (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null
);

create index pncp_situacoes_resultado_item_idx1 on audit.pncp_situacoes_resultado_item(dh_audit,oper_audit,usuario_audit);
create index pncp_situacoes_resultado_item_idx2 on audit.pncp_situacoes_resultado_item(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_situacoes_resultado_item to sgisis;
grant select on audit.pncp_situacoes_resultado_item to sgitec;
grant select on audit.pncp_situacoes_resultado_item to consulta;

create trigger audit_bi before insert on pncp.situacoes_resultado_item for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.situacoes_resultado_item for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.situacoes_resultado_item for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.situacoes_resultado_item for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.situacoes_resultado_item for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.tipos_documentos
 */
create table pncp.tipos_documentos(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id integer primary key,
	nome text not null,
	descricao text
);
comment on table pncp.tipos_documentos is
  'Domínio do PNCP para tipo de documento/arquivo publicado (tipoDocumentoId/Nome/Descricao).';

grant select, insert, update, delete on pncp.tipos_documentos to sgisis;
grant select, insert, update, delete on pncp.tipos_documentos to sgitec;
grant select on pncp.tipos_documentos to consulta;

create table audit.pncp_tipos_documentos (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id integer not null,
	nome text not null,
	descricao text
);

create index pncp_tipos_documentos_idx1 on audit.pncp_tipos_documentos(dh_audit,oper_audit,usuario_audit);
create index pncp_tipos_documentos_idx2 on audit.pncp_tipos_documentos(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_tipos_documentos to sgisis;
grant select on audit.pncp_tipos_documentos to sgitec;
grant select on audit.pncp_tipos_documentos to consulta;

create trigger audit_bi before insert on pncp.tipos_documentos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.tipos_documentos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.tipos_documentos for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.tipos_documentos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.tipos_documentos for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.contratacoes
 */
create table pncp.contratacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	numero_controle_pncp varchar(40) not null,

	cnpj_orgao varchar(14) not null,
	ano_compra integer not null,
	sequencial_compra integer not null,
	numero_compra varchar(50),
	processo text,

	orgao_entidade_id integer not null references pncp.orgaos(id) on delete restrict,
	unidade_orgao_id integer not null references pncp.orgaos_unidades(id) on delete restrict,
	orgao_subrogado_id integer references pncp.orgaos(id) on delete restrict,
	unidade_subrogada_id integer references pncp.orgaos_unidades(id) on delete restrict,

	modalidade_id integer references pncp.modalidades_contratacao(id),
	modo_disputa_id integer references pncp.modos_disputa(id),
	tipo_instrumento_convocatorio_id integer references pncp.tipos_instrumentos_convocatorios(id),
	amparo_legal_id integer references pncp.amparos_legais(id),
	situacao_compra_id integer references pncp.situacoes_compra(id),
	orcamento_sigiloso_id integer references pncp.tipos_orcamento_sigiloso(id),

	objeto_compra text,
	informacao_complementar text,
	justificativa_presencial text,
	srp boolean,
	emenda_parlamentar boolean,
	existe_resultado boolean,

	valor_total_estimado numeric(18,2),
	valor_total_homologado numeric(18,2),

	link_sistema_origem text,
	link_processo_eletronico text,

	data_publicacao_pncp timestamp(0),
	data_abertura_proposta timestamp(0),
	data_encerramento_proposta timestamp(0),
	data_inclusao_pncp timestamp(0),
	data_atualizacao_pncp timestamp(0),
	data_atualizacao_global_pncp timestamp(0),
	usuario_nome text,

	dados_json jsonb not null,

	primeira_sincronizacao_em timestamp(0) default current_timestamp not null,
	ultima_sincronizacao_em timestamp(0) default current_timestamp not null,

	constraint contratacoes_pkey primary key (id),
	constraint contratacoes_ukey_numero_controle unique (conta_id, numero_controle_pncp),
	constraint contratacoes_ukey_cnpj_ano_sequencial unique (conta_id, cnpj_orgao, ano_compra, sequencial_compra),
	constraint contratacoes_numero_controle_chk check (numero_controle_pncp ~ '^[0-9]{14}-[0-9]-[0-9]{6}/[0-9]{4}$'),
	constraint contratacoes_cnpj_orgao_chk check (cnpj_orgao ~ '^[0-9]{14}$'),
	constraint contratacoes_ano_compra_chk check (ano_compra between 2000 and 2100),
	constraint contratacoes_sequencial_compra_chk check (sequencial_compra > 0)
);

comment on table pncp.contratacoes is
  'Espelho de uma contratação (compra) importada do PNCP, isolado por Conta (conta_id) — '
  'cada conta mantém sua própria cópia das contratações que optou por acompanhar/importar. '
  'PONTO DE EXTENSÃO PARA O MÓDULO DISPUTA: a futura tabela disputa.disputa deverá conter a '
  'coluna opcional "contratacao_pncp_id integer" com uma foreign key '
  '"contratacao_pncp_id references pncp.contratacoes(id) ON DELETE SET NULL" (ou similar), '
  'permitindo vincular a disputa à contratação PNCP de origem e preencher automaticamente '
  'os itens da disputa a partir de pncp.contratacoes_itens. Nenhuma FK nesse sentido é criada aqui, '
  'pois a tabela disputa.disputa ainda não existe neste repositório.';

grant select, insert, update, delete on pncp.contratacoes to sgisis;
grant select, insert, update, delete on pncp.contratacoes to sgitec;
grant select on pncp.contratacoes to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_conta_id on pncp.contratacoes (conta_id);
create index ix_contratacoes_cnpj_orgao on pncp.contratacoes (cnpj_orgao);
create index ix_contratacoes_ano_compra on pncp.contratacoes (ano_compra);
create index ix_contratacoes_situacao on pncp.contratacoes (situacao_compra_id);
create index ix_contratacoes_modalidade on pncp.contratacoes (modalidade_id);
create index ix_contratacoes_data_publicacao on pncp.contratacoes (data_publicacao_pncp);
create index ix_contratacoes_orgao_entidade on pncp.contratacoes (orgao_entidade_id);
create index ix_contratacoes_unidade_orgao on pncp.contratacoes (unidade_orgao_id);
create index ix_contratacoes_orgao_subrogado on pncp.contratacoes (orgao_subrogado_id) where orgao_subrogado_id is not null;
create index ix_contratacoes_dados_json on pncp.contratacoes using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes
 */
create table audit.pncp_contratacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,

	numero_controle_pncp varchar(40) not null,

	cnpj_orgao varchar(14) not null,
	ano_compra integer not null,
	sequencial_compra integer not null,
	numero_compra varchar(50),
	processo text,

	orgao_entidade_id integer not null,
	unidade_orgao_id integer not null,
	orgao_subrogado_id integer,
	unidade_subrogada_id integer,

	modalidade_id integer,
	modo_disputa_id integer,
	tipo_instrumento_convocatorio_id integer,
	amparo_legal_id integer,
	situacao_compra_id integer,
	orcamento_sigiloso_id integer,

	objeto_compra text,
	informacao_complementar text,
	justificativa_presencial text,
	srp boolean,
	emenda_parlamentar boolean,
	existe_resultado boolean,

	valor_total_estimado numeric(18,2),
	valor_total_homologado numeric(18,2),

	link_sistema_origem text,
	link_processo_eletronico text,

	data_publicacao_pncp timestamp(0),
	data_abertura_proposta timestamp(0),
	data_encerramento_proposta timestamp(0),
	data_inclusao_pncp timestamp(0),
	data_atualizacao_pncp timestamp(0),
	data_atualizacao_global_pncp timestamp(0),
	usuario_nome text,

	dados_json jsonb not null,

	primeira_sincronizacao_em timestamp(0) not null,
	ultima_sincronizacao_em timestamp(0) not null
);

create index pncp_contratacoes_idx1 on audit.pncp_contratacoes(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_idx2 on audit.pncp_contratacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes to sgisis;
grant select on audit.pncp_contratacoes to sgitec;
grant select on audit.pncp_contratacoes to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.contratacoes_itens
 *
 * Filha de pncp.contratacoes (via contratacao_id). Tem id serial próprio como PK;
 * numero_item já vem da API como sequência única dentro da contratação, então é a
 * chave natural, garantida pelo unique(contratacao_id, numero_item).
 */
create table pncp.contratacoes_itens(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	contratacao_id integer not null,
	numero_item integer not null,
	descricao text,
	material_ou_servico varchar(1),   -- 'M' ou 'S'
	material_ou_servico_nome text,
	valor_unitario_estimado numeric(18,4),
	valor_total numeric(18,2),
	quantidade numeric(18,4),
	unidade_medida text,
	orcamento_sigiloso boolean,
	item_categoria_id integer references pncp.categorias_itens(id),
	criterio_julgamento_id integer references pncp.criterios_julgamento(id),
	situacao_item_id integer references pncp.situacoes_item(id),      -- API: situacaoCompraItem
	tipo_beneficio_id integer references pncp.tipos_beneficios(id),
	incentivo_produtivo_basico boolean,
	tem_resultado boolean,
	data_inclusao_pncp timestamp(0),
	data_atualizacao_pncp timestamp(0),
	dados_json jsonb not null,

	constraint contratacoes_itens_pkey primary key (id),
	constraint contratacoes_itens_ukey unique (contratacao_id, numero_item),
	constraint contratacoes_itens_material_ou_servico_chk check (material_ou_servico is null or material_ou_servico in ('M','S')),
	foreign key (contratacao_id) references pncp.contratacoes(id) on delete cascade
);
comment on table pncp.contratacoes_itens is 'Item de uma contratação PNCP (endpoint .../itens).';

grant select, insert, update, delete on pncp.contratacoes_itens to sgisis;
grant select, insert, update, delete on pncp.contratacoes_itens to sgitec;
grant select on pncp.contratacoes_itens to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_itens_conta_id on pncp.contratacoes_itens (conta_id);
create index ix_contratacoes_itens_situacao on pncp.contratacoes_itens (situacao_item_id);
create index ix_contratacoes_itens_tem_resultado on pncp.contratacoes_itens (tem_resultado) where tem_resultado = true;
create index ix_contratacoes_itens_dados_json on pncp.contratacoes_itens using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes_itens
 */
create table audit.pncp_contratacoes_itens (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,

	contratacao_id integer not null,
	numero_item integer not null,
	descricao text,
	material_ou_servico varchar(1),
	material_ou_servico_nome text,
	valor_unitario_estimado numeric(18,4),
	valor_total numeric(18,2),
	quantidade numeric(18,4),
	unidade_medida text,
	orcamento_sigiloso boolean,
	item_categoria_id integer,
	criterio_julgamento_id integer,
	situacao_item_id integer,
	tipo_beneficio_id integer,
	incentivo_produtivo_basico boolean,
	tem_resultado boolean,
	data_inclusao_pncp timestamp(0),
	data_atualizacao_pncp timestamp(0),
	dados_json jsonb not null
);

create index pncp_contratacoes_itens_idx1 on audit.pncp_contratacoes_itens(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_itens_idx2 on audit.pncp_contratacoes_itens(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_itens to sgisis;
grant select on audit.pncp_contratacoes_itens to sgitec;
grant select on audit.pncp_contratacoes_itens to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes_itens for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_itens for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_itens for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_itens for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_itens for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.contratacoes_fontes_orcamentarias
 *
 * Filha de pncp.contratacoes (via contratacao_id). A API não numera as fontes
 * orçamentárias, então mantemos um "id" sintético — gerado nativamente via
 * serial, sem trigger própria.
 */
create table pncp.contratacoes_fontes_orcamentarias(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	contratacao_id integer not null,
	codigo integer,
	nome text,
	descricao text,
	data_inclusao_pncp timestamp(0),
	dados_json jsonb not null,

	constraint contratacoes_fontes_orcamentarias_pkey primary key (id),
	foreign key (contratacao_id) references pncp.contratacoes(id) on delete cascade
);
comment on table pncp.contratacoes_fontes_orcamentarias is
  'Fontes orçamentárias declaradas na contratação (array fontesOrcamentarias da API).';

grant select, insert, update, delete on pncp.contratacoes_fontes_orcamentarias to sgisis;
grant select, insert, update, delete on pncp.contratacoes_fontes_orcamentarias to sgitec;
grant select on pncp.contratacoes_fontes_orcamentarias to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_fontes_orcamentarias_conta_id on pncp.contratacoes_fontes_orcamentarias (conta_id);
create index ix_contratacoes_fontes_orcamentarias_dados_json on pncp.contratacoes_fontes_orcamentarias using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes_fontes_orcamentarias
 */
create table audit.pncp_contratacoes_fontes_orcamentarias (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,

	contratacao_id integer not null,
	codigo integer,
	nome text,
	descricao text,
	data_inclusao_pncp timestamp(0),
	dados_json jsonb not null
);

create index pncp_contratacoes_fontes_orcamentarias_idx1 on audit.pncp_contratacoes_fontes_orcamentarias(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_fontes_orcamentarias_idx2 on audit.pncp_contratacoes_fontes_orcamentarias(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_fontes_orcamentarias to sgisis;
grant select on audit.pncp_contratacoes_fontes_orcamentarias to sgitec;
grant select on audit.pncp_contratacoes_fontes_orcamentarias to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes_fontes_orcamentarias for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_fontes_orcamentarias for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_fontes_orcamentarias for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_fontes_orcamentarias for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_fontes_orcamentarias for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.contratacoes_arquivos
 *
 * Filha de pncp.contratacoes (via contratacao_id). Tem id serial próprio como PK;
 * sequencial_documento já vem da API como sequência única dentro da contratação,
 * então é a chave natural, garantida pelo unique(contratacao_id, sequencial_documento).
 */
create table pncp.contratacoes_arquivos(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	contratacao_id integer not null,
	sequencial_documento integer not null,
	titulo text,
	tipo_documento_id integer references pncp.tipos_documentos(id),
	uri text,
	url text,
	status_ativo boolean,
	data_publicacao_pncp timestamp(0),
	dados_json jsonb not null,

	constraint contratacoes_arquivos_pkey primary key (id),
	constraint contratacoes_arquivos_ukey unique (contratacao_id, sequencial_documento),
	foreign key (contratacao_id) references pncp.contratacoes(id) on delete cascade
);
comment on table pncp.contratacoes_arquivos is 'Documento/arquivo publicado para a contratação (endpoint .../arquivos).';

grant select, insert, update, delete on pncp.contratacoes_arquivos to sgisis;
grant select, insert, update, delete on pncp.contratacoes_arquivos to sgitec;
grant select on pncp.contratacoes_arquivos to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_arquivos_conta_id on pncp.contratacoes_arquivos (conta_id);
create index ix_contratacoes_arquivos_tipo on pncp.contratacoes_arquivos (tipo_documento_id);
create index ix_contratacoes_arquivos_dados_json on pncp.contratacoes_arquivos using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes_arquivos
 */
create table audit.pncp_contratacoes_arquivos (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,

	contratacao_id integer not null,
	sequencial_documento integer not null,
	titulo text,
	tipo_documento_id integer,
	uri text,
	url text,
	status_ativo boolean,
	data_publicacao_pncp timestamp(0),
	dados_json jsonb not null
);

create index pncp_contratacoes_arquivos_idx1 on audit.pncp_contratacoes_arquivos(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_arquivos_idx2 on audit.pncp_contratacoes_arquivos(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_arquivos to sgisis;
grant select on audit.pncp_contratacoes_arquivos to sgitec;
grant select on audit.pncp_contratacoes_arquivos to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes_arquivos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_arquivos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_arquivos for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_arquivos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_arquivos for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.contratacoes_situacoes
 *
 * Filha de pncp.contratacoes (via contratacao_id). Log append-only gerado pela
 * própria rotina de sincronização; id é serial, gerado nativamente pelo Postgres.
 */
create table pncp.contratacoes_situacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	contratacao_id integer not null,
	situacao_compra_id integer not null references pncp.situacoes_compra(id),
	existe_resultado boolean,
	valor_total_homologado numeric(18,2),
	detectado_em timestamp(0) default current_timestamp not null,
	origem varchar(30) default 'sincronizacao_api' not null,

	constraint contratacoes_situacoes_pkey primary key (id),
	foreign key (contratacao_id) references pncp.contratacoes(id) on delete cascade
);
comment on table pncp.contratacoes_situacoes is
  'Registro append-only de cada mudança de situação observada para a contratação, '
  'gerado pela rotina de sincronização sempre que situacao_compra_id difere do último valor conhecido. '
  'Permite reconstruir a linha do tempo da contratação para o "acompanhamento" do sistema.';

grant select, insert, update, delete on pncp.contratacoes_situacoes to sgisis;
grant select, insert, update, delete on pncp.contratacoes_situacoes to sgitec;
grant select on pncp.contratacoes_situacoes to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_situacoes_conta_id on pncp.contratacoes_situacoes (conta_id);
create index ix_contratacoes_situacoes_contratacao_data on pncp.contratacoes_situacoes (contratacao_id, detectado_em desc);

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes_situacoes
 */
create table audit.pncp_contratacoes_situacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,

	contratacao_id integer not null,
	situacao_compra_id integer not null,
	existe_resultado boolean,
	valor_total_homologado numeric(18,2),
	detectado_em timestamp(0) not null,
	origem varchar(30) not null
);

create index pncp_contratacoes_situacoes_idx1 on audit.pncp_contratacoes_situacoes(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_situacoes_idx2 on audit.pncp_contratacoes_situacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_situacoes to sgisis;
grant select on audit.pncp_contratacoes_situacoes to sgitec;
grant select on audit.pncp_contratacoes_situacoes to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes_situacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_situacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_situacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_situacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_situacoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * TABELA: pncp.contratacoes_itens_resultados
 *
 * Filha de pncp.contratacoes_itens (via contratacao_id + numero_item). Tem id serial
 * próprio como PK; sequencial_resultado já vem da API como sequência única dentro do
 * item, garantida pelo unique(contratacao_id, numero_item, sequencial_resultado).
 */
create table pncp.contratacoes_itens_resultados(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null references adm.contas,
	id serial,

	contratacao_id integer not null,
	numero_item integer not null,
	sequencial_resultado integer default 1 not null,
	ni_fornecedor varchar(30),
	nome_razao_social_fornecedor text,
	valor_total_homologado numeric(18,2),
	situacao_compra_item_resultado_id integer references pncp.situacoes_resultado_item(id),
	data_resultado timestamp(0),
	dados_json jsonb not null,

	constraint contratacoes_itens_resultados_pkey primary key (id),
	constraint contratacoes_itens_resultados_ukey unique (contratacao_id, numero_item, sequencial_resultado),
	foreign key (contratacao_id, numero_item) references pncp.contratacoes_itens(contratacao_id, numero_item) on delete cascade
);
comment on table pncp.contratacoes_itens_resultados is
  'Resultado (fornecedor vencedor/valor homologado) de um item de contratação, '
  'endpoint .../itens/{numeroItem}/resultados. Colunas são uma estimativa baseada no manual do PNCP '
  '(endpoint não testado nesta conversa) — ajustar quando o payload real for validado; dados_json '
  'preserva tudo o que a API retornar independentemente das colunas modeladas.';

grant select, insert, update, delete on pncp.contratacoes_itens_resultados to sgisis;
grant select, insert, update, delete on pncp.contratacoes_itens_resultados to sgitec;
grant select on pncp.contratacoes_itens_resultados to consulta;
grant usage on all sequences in schema pncp to sgisis;
grant usage on all sequences in schema pncp to sgitec;

create index ix_contratacoes_itens_resultados_conta_id on pncp.contratacoes_itens_resultados (conta_id);
create index ix_contratacoes_itens_resultados_ni_fornecedor on pncp.contratacoes_itens_resultados (ni_fornecedor);
create index ix_contratacoes_itens_resultados_dados_json on pncp.contratacoes_itens_resultados using gin (dados_json jsonb_path_ops);

/******************************************************************************************
 * TABELA: audit.pncp_contratacoes_itens_resultados
 */
create table audit.pncp_contratacoes_itens_resultados (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	id integer not null,

	contratacao_id integer not null,
	numero_item integer not null,
	sequencial_resultado integer default 1 not null,
	ni_fornecedor varchar(30),
	nome_razao_social_fornecedor text,
	valor_total_homologado numeric(18,2),
	situacao_compra_item_resultado_id integer,
	data_resultado timestamp(0),
	dados_json jsonb not null
);

create index pncp_contratacoes_itens_resultados_idx1 on audit.pncp_contratacoes_itens_resultados(dh_audit,oper_audit,usuario_audit);
create index pncp_contratacoes_itens_resultados_idx2 on audit.pncp_contratacoes_itens_resultados(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contratacoes_itens_resultados to sgisis;
grant select on audit.pncp_contratacoes_itens_resultados to sgitec;
grant select on audit.pncp_contratacoes_itens_resultados to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.contratacoes_itens_resultados for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contratacoes_itens_resultados for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contratacoes_itens_resultados for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contratacoes_itens_resultados for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contratacoes_itens_resultados for each row execute function audit.func_audit_after();
