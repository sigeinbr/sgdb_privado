/******************************************************************************************
 * Radar de Licitações — menção calculada pela API (Fase 2)
 *
 * Remove pncp.empresas_mencoes (a menção passa a ser calculada sobre
 * pncp.contratacoes_mensagens). Só aplicar depois do deploy da API nova: o código antigo
 * ainda lê e grava nesta tabela.
 *
 * Os triggers de auditoria caem junto com a tabela. Os espelhos audit.pncp_empresas_mencoes,
 * audit.pncp_contratacoes_mensagens_mencoes e audit.pncp_mencoes_notificacoes_enviadas
 * ficam congelados como histórico e não são tocados.
 */
drop table pncp.empresas_mencoes;
