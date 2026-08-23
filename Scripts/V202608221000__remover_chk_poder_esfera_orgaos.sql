/******************************************************************************************
 * pncp.orgaos.poder_id/esfera_id: remover CHECKs de domínio incompletos
 *
 * orgaos_poder_id_chk só previa ('L','E','J'). A importação da contratação
 * 29141322000132-1-000197/2026 (Município de Piraí) trouxe orgaoEntidade.poderId = 'N'
 * (Não se aplica) da API real do PNCP, valor válido do domínio mas ausente da lista
 * antecipada, travando o insert em pncp.orgaos.
 *
 * Mesmo motivo que já levou à remoção das FKs de domínio em V202608201100
 * (achatamento das tabelas de domínio): a lista oficial completa de códigos que a
 * API do PNCP pode retornar para esses campos não é conhecida, então travar por
 * CHECK arrisca repetir o mesmo bloqueio a cada valor novo. poder_id/esfera_id
 * seguem gravando o código bruto enviado pela API, sem validação.
 */
alter table pncp.orgaos drop constraint orgaos_poder_id_chk;
alter table pncp.orgaos drop constraint orgaos_esfera_id_chk;
