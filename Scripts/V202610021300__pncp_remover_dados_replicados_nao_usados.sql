/******************************************************************************************
 * Radar de Licitações — remoção dos dados PNCP replicados que o radar não usa
 *
 * A réplica completa do PNCP passou para o projeto/banco pncp (consumido via pncp-api). O
 * schema pncp do target fica só com o que o radar_licitacoes efetivamente lê, mais as tabelas
 * de negócio do próprio radar (mensagens, empresas, menções, notificações).
 *
 * 1. Tabelas sem uso (vazias, sem código ou só escritas e nunca lidas) e seus espelhos audit:
 *      pncp.comprasnet_sessoes, pncp.contas_contratacoes_itens, pncp.contratacoes_convocacoes,
 *      pncp.contratacoes_situacoes, pncp.contratacoes_fontes_orcamentarias
 * 2. Colunas nunca lidas das tabelas que ficam (dados_json em todas, ids de domínio sem
 *    leitura, marcas de sincronização, etc.), replicado nos espelhos audit.
 *
 * Os espelhos congelados do bloco anterior (audit.pncp_contas_contratacoes,
 * audit.pncp_contratacoes_mensagens_mencoes, audit.pncp_mencoes_notificacoes_enviadas) não
 * são tocados.
 *
 * Deploy coordenado com o radar_licitacoes: a versão anterior do radar mapeia estas colunas
 * nas entidades e grava dados_json (NOT NULL).
 */

/******************************************************************************************
 * 1. Tabelas sem uso — nenhuma tabela que fica referencia estas
 */
drop table pncp.comprasnet_sessoes;
drop table audit.pncp_comprasnet_sessoes;

drop table pncp.contas_contratacoes_itens;
drop table audit.pncp_contas_contratacoes_itens;

drop table pncp.contratacoes_convocacoes;
drop table audit.pncp_contratacoes_convocacoes;

drop table pncp.contratacoes_situacoes;
drop table audit.pncp_contratacoes_situacoes;

drop table pncp.contratacoes_fontes_orcamentarias;
drop table audit.pncp_contratacoes_fontes_orcamentarias;

/******************************************************************************************
 * 2. Colunas nunca lidas pelo radar
 *
 * Índices (GIN de dados_json, ix_contratacoes_itens_situacao, ix_contratacoes_arquivos_tipo,
 * ix_orgaos_unidades_uf_sigla) e CHECKs que dependem só delas caem junto. No audit, if exists:
 * nem todo espelho tem todas as colunas.
 */

-- pncp.contratacoes
alter table pncp.contratacoes
    drop column dados_json,
    drop column primeira_sincronizacao_em,
    drop column ultima_sincronizacao_em,
    drop column modo_disputa_id,
    drop column tipo_instrumento_convocatorio_id,
    drop column amparo_legal_id,
    drop column amparo_legal_descricao,
    drop column orcamento_sigiloso_id;

alter table audit.pncp_contratacoes
    drop column if exists dados_json,
    drop column if exists primeira_sincronizacao_em,
    drop column if exists ultima_sincronizacao_em,
    drop column if exists modo_disputa_id,
    drop column if exists tipo_instrumento_convocatorio_id,
    drop column if exists amparo_legal_id,
    drop column if exists amparo_legal_descricao,
    drop column if exists orcamento_sigiloso_id;

-- pncp.contratacoes_itens
alter table pncp.contratacoes_itens
    drop column dados_json,
    drop column material_ou_servico,
    drop column material_ou_servico_nome,
    drop column orcamento_sigiloso,
    drop column item_categoria_id,
    drop column item_categoria_nome,
    drop column criterio_julgamento_id,
    drop column criterio_julgamento_nome,
    drop column situacao_item_id,
    drop column situacao_item_nome,
    drop column tipo_beneficio_id,
    drop column tipo_beneficio_nome,
    drop column incentivo_produtivo_basico,
    drop column data_inclusao_pncp,
    drop column data_atualizacao_pncp;

alter table audit.pncp_contratacoes_itens
    drop column if exists dados_json,
    drop column if exists material_ou_servico,
    drop column if exists material_ou_servico_nome,
    drop column if exists orcamento_sigiloso,
    drop column if exists item_categoria_id,
    drop column if exists item_categoria_nome,
    drop column if exists criterio_julgamento_id,
    drop column if exists criterio_julgamento_nome,
    drop column if exists situacao_item_id,
    drop column if exists situacao_item_nome,
    drop column if exists tipo_beneficio_id,
    drop column if exists tipo_beneficio_nome,
    drop column if exists incentivo_produtivo_basico,
    drop column if exists data_inclusao_pncp,
    drop column if exists data_atualizacao_pncp;

-- pncp.contratacoes_itens_resultados
alter table pncp.contratacoes_itens_resultados
    drop column dados_json;

alter table audit.pncp_contratacoes_itens_resultados
    drop column if exists dados_json;

-- pncp.contratacoes_arquivos
alter table pncp.contratacoes_arquivos
    drop column dados_json,
    drop column tipo_documento_id,
    drop column tipo_documento_nome,
    drop column tipo_documento_descricao,
    drop column status_ativo;

alter table audit.pncp_contratacoes_arquivos
    drop column if exists dados_json,
    drop column if exists tipo_documento_id,
    drop column if exists tipo_documento_nome,
    drop column if exists tipo_documento_descricao,
    drop column if exists status_ativo;

-- pncp.orgaos
alter table pncp.orgaos
    drop column dados_json,
    drop column poder_id,
    drop column esfera_id,
    drop column ultima_sincronizacao_em;

alter table audit.pncp_orgaos
    drop column if exists dados_json,
    drop column if exists poder_id,
    drop column if exists esfera_id,
    drop column if exists ultima_sincronizacao_em;

-- pncp.orgaos_unidades
alter table pncp.orgaos_unidades
    drop column dados_json,
    drop column uf_sigla,
    drop column uf_nome,
    drop column municipio_nome,
    drop column codigo_ibge;

alter table audit.pncp_orgaos_unidades
    drop column if exists dados_json,
    drop column if exists uf_sigla,
    drop column if exists uf_nome,
    drop column if exists municipio_nome,
    drop column if exists codigo_ibge;

-- pncp.contratacoes_mensagens
alter table pncp.contratacoes_mensagens
    drop column dados_json,
    drop column prazo_trecho_fonte;

alter table audit.pncp_contratacoes_mensagens
    drop column if exists dados_json,
    drop column if exists prazo_trecho_fonte;

/******************************************************************************************
 * 3. Comentário
 */
comment on table pncp.contratacoes is
  'Referência local da contratação PNCP usada pelo radar (vínculos, mensagens, menções, '
  'situacao_calculada). O dado completo do PNCP está no banco pncp.';
