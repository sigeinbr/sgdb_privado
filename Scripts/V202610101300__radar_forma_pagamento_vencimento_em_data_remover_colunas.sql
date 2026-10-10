/******************************************************************************************
 * Radar de Licitacoes - forma de pagamento recorrente e vencimento em data (Bloco 2)
 *
 * Aplicar somente depois do deploy do codigo novo (que nao le nem grava as colunas abaixo).
 * O NOT NULL de adm.cobrancas.operacao (item 2.4) ja foi aplicado em
 * V202610101200__cobrancas_operacao_not_null.sql.
 *
 * As colunas correspondentes em audit.* sao mantidas (historico; ja aceitam NULL).
 */
drop index adm.assinaturas_vigente_ate_idx;

alter table adm.assinaturas drop column vigente_ate;
alter table adm.assinaturas drop column ciclo_inicio;

alter table adm.cobrancas drop constraint cobrancas_motivo_chk;
alter table adm.cobrancas drop column motivo;

alter table adm.avisos_vencimento_enviados drop column vigente_ate;
