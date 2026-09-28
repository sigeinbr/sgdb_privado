/******************************************************************************************
 * Radar de Licitações — fase "em_julgamento" e coluna persistida situacao_calculada
 *
 * situacao_compra_id/situacao_compra_nome (espelho bruto do PNCP, sempre travado no
 * primeiro valor divulgado) não são tocados por esta migration nem pelo código do backend —
 * situacao_calculada é uma coluna própria, calculada e mantida pelo backend (ver
 * api/src/pncp/contratacoes/situacao-calculada.util.ts).
 */

alter table pncp.contratacoes
	add column situacao_calculada varchar(20);

alter table audit.pncp_contratacoes
	add column situacao_calculada varchar(20);

/******************************************************************************************
 * Backfill: mesma regra usada pelo backend (calcularFaseContratacao), na ordem de
 * prioridade homologado > em_julgamento > datas — homologado sempre vence, mesmo para quem
 * já recebeu a mensagem de julgamento antes de ter resultado.
 */
update pncp.contratacoes c set situacao_calculada = case
		when c.existe_resultado then 'homologado'
		when exists (
			select 1
			from pncp.contratacoes_mensagens m
			where m.contratacao_id = c.id
				and m.texto ilike '%etapa de julgamento de propostas foi iniciada%'
		) then 'em_julgamento'
		when now() < c.data_abertura_proposta then 'aguardando_abertura'
		when now() < c.data_encerramento_proposta then 'recebendo_propostas'
		else 'em_disputa'
	end;

alter table pncp.contratacoes
	alter column situacao_calculada set not null,
	add constraint contratacoes_situacao_calculada_chk check (
		situacao_calculada in (
			'aguardando_abertura',
			'recebendo_propostas',
			'em_disputa',
			'em_julgamento',
			'homologado'
		)
	);

create index ix_contratacoes_situacao_calculada on pncp.contratacoes (situacao_calculada);
