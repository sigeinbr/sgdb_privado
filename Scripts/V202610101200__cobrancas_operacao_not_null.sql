/******************************************************************************************
 * Radar de Licitacoes - cobranca pelo Asaas (Bloco 2 - apos o deploy do codigo novo)
 *
 * Preenche operacao nas linhas inseridas pelo codigo antigo (entre o Bloco 1 e o deploy)
 * e torna adm.cobrancas.operacao NOT NULL. O espelho audit.adm_cobrancas continua
 * aceitando NULL (historico).
 */
update adm.cobrancas
   set operacao = case motivo
                    when 'ciclo' then 'novo_ciclo'
                    when 'upgrade_prorata' then 'upgrade'
                    when 'troca_vencimento_prorata' then 'troca_dia'
                  end
 where operacao is null;

alter table adm.cobrancas alter column operacao set not null;
