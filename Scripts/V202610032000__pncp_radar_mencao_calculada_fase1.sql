/******************************************************************************************
 * Radar de Licitações — menção calculada pela API (Fase 1, compatível com API atual e nova)
 *
 * pncp.empresas_mencoes será eliminada: a menção passa a ser calculada sobre
 * pncp.contratacoes_mensagens a partir de identificador_destinatario, identificador_remetente
 * e do texto da mensagem. Esta fase prepara o terreno sem derrubar nada:
 *
 * 1. Extensão unaccent (busca sem acento no texto das mensagens)
 * 2. pncp.notificacoes_enviadas: troca a FK para empresas_mencoes por FKs diretas para
 *    pncp.contratacoes_mensagens e pncp.empresas (nenhuma coluna criada/removida, então o
 *    espelho audit.pncp_notificacoes_enviadas não muda)
 * 3. Índices de pncp.contratacoes_mensagens para as consultas novas
 *
 * A Fase 2 (DROP TABLE pncp.empresas_mencoes) é uma migration posterior, só após a
 * confirmação do deploy da API.
 */

/******************************************************************************************
 * 1. Extensão unaccent
 */
create extension if not exists unaccent schema public;

/******************************************************************************************
 * 2. FKs de pncp.notificacoes_enviadas
 */
alter table pncp.notificacoes_enviadas
  drop constraint notificacoes_enviadas_mencao_fkey;

alter table pncp.notificacoes_enviadas
  add constraint notificacoes_enviadas_mensagem_fkey
    foreign key (mensagem_id) references pncp.contratacoes_mensagens(id) on delete cascade,
  add constraint notificacoes_enviadas_empresa_fkey
    foreign key (empresa_id) references pncp.empresas(id) on delete cascade;

/******************************************************************************************
 * 3. Índices de pncp.contratacoes_mensagens
 */
create index if not exists ix_contratacoes_mensagens_contratacao_data
  on pncp.contratacoes_mensagens (contratacao_id, data_hora desc);
create index if not exists ix_contratacoes_mensagens_destinatario
  on pncp.contratacoes_mensagens (identificador_destinatario);
create index if not exists ix_contratacoes_mensagens_remetente
  on pncp.contratacoes_mensagens (identificador_remetente);
