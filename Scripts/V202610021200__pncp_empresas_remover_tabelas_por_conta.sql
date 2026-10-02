/******************************************************************************************
 * Radar de Licitações — empresas por conta (remoção das tabelas antigas)
 *
 * Continuação de V202610021000/V202610021100. Remove as tabelas por conta, substituídas pelas
 * tabelas por empresa:
 *   pncp.mencoes_notificacoes_enviadas  -> pncp.notificacoes_enviadas
 *   pncp.contratacoes_mensagens_mencoes -> pncp.empresas_mencoes
 *   pncp.contas_contratacoes            -> pncp.empresas_contratacoes
 *
 * Os espelhos audit.pncp_contas_contratacoes, audit.pncp_contratacoes_mensagens_mencoes e
 * audit.pncp_mencoes_notificacoes_enviadas FICAM, com o nome original: o primeiro é o
 * histórico de cobrança (monitorada) anterior a 2026-10 e não pode ser apagado.
 */

/******************************************************************************************
 * Trava: a aplicação precisa ter parado de escrever nas tabelas antigas. Qualquer escrita
 * auditada nelas nas últimas 2 horas aborta a migration (e o deploy) — sinal de que ainda
 * há versão antiga da aplicação ou do job rodando, ou de que o deploy é recente demais para
 * estar validado.
 */
do $$
declare
  v_ultima_escrita timestamp;
begin
  select max(dh_audit) into v_ultima_escrita
    from (
      select dh_audit from audit.pncp_contas_contratacoes
      union all
      select dh_audit from audit.pncp_contratacoes_mensagens_mencoes
      union all
      select dh_audit from audit.pncp_mencoes_notificacoes_enviadas
    ) escritas;

  if v_ultima_escrita > current_timestamp - interval '2 hours' then
    raise exception 'Tabelas por conta ainda receberam escrita em % (menos de 2 horas). A aplicação parou de usá-las?', v_ultima_escrita;
  end if;
end;
$$;

/******************************************************************************************
 * Última passada do backfill: copia só o que o job gravou nas tabelas antigas entre
 * V202610021100 e o deploy da aplicação — linhas que nunca passaram pelas tabelas novas.
 * Linhas copiadas antes e já excluídas pela aplicação não voltam. A procedure aborta se
 * alguma linha pendente ficar sem destino.
 */
call pncp.proc_migrar_empresas_por_conta(true);

drop procedure pncp.proc_migrar_empresas_por_conta(boolean);

/******************************************************************************************
 * Remoção — nesta ordem, por causa das FKs
 */
drop table pncp.mencoes_notificacoes_enviadas;
drop table pncp.contratacoes_mensagens_mencoes;
drop table pncp.contas_contratacoes;

comment on table audit.pncp_contas_contratacoes is
  'CONGELADA desde 2026-10: histórico de pncp.contas_contratacoes (removida), incluindo a '
  'cobrança (monitorada) anterior às empresas por conta. Sucessora: audit.pncp_empresas_contratacoes.';
comment on table audit.pncp_contratacoes_mensagens_mencoes is
  'CONGELADA desde 2026-10: histórico de pncp.contratacoes_mensagens_mencoes (removida). '
  'Sucessora: audit.pncp_empresas_mencoes.';
comment on table audit.pncp_mencoes_notificacoes_enviadas is
  'CONGELADA desde 2026-10: histórico de pncp.mencoes_notificacoes_enviadas (removida). '
  'Sucessora: audit.pncp_notificacoes_enviadas.';
