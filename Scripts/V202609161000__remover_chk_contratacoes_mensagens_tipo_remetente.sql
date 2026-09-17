/******************************************************************************************
 * pncp.contratacoes_mensagens.tipo_remetente: remover CHECK de domínio incompleto
 *
 * contratacoes_mensagens_tipo_remetente_chk só previa ('0','1'). Erros em produção
 * (contratações 29115474000160-1-000554/2026 e 03006392000194-1-000038/2026) mostraram
 * que a API real do PNCP retorna outros valores de tipoRemetente, travando o insert em
 * pncp.contratacoes_mensagens.
 *
 * Mesmo motivo que já levou à remoção das FKs de domínio em V202608201100 e dos CHECKs
 * de poder_id/esfera_id em V202608221000: a lista oficial completa de códigos que a API
 * do PNCP pode retornar não é conhecida, então travar por CHECK arrisca repetir o mesmo
 * bloqueio a cada valor novo. tipo_remetente segue gravando o código bruto enviado pela
 * API, sem validação.
 */
alter table pncp.contratacoes_mensagens drop constraint contratacoes_mensagens_tipo_remetente_chk;
