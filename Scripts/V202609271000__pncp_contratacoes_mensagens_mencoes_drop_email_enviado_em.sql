/******************************************************************************************
 * Aposentadoria de pncp.contratacoes_mensagens_mencoes.email_enviado_em
 *
 * O app já migrou para pncp.mencoes_notificacoes_enviadas (V202609251300). Antes de
 * dropar a coluna, repete o mesmo backfill (idempotente via ON CONFLICT DO NOTHING) para
 * capturar qualquer linha gravada por uma instância antiga do app ainda em voo entre o
 * backfill original e este deploy.
 */
insert into pncp.mencoes_notificacoes_enviadas (conta_id, mensagem_id, usuario_login, canal, enviado_em)
select distinct
	m.conta_id,
	m.mensagem_id,
	gpu.usuario_login,
	'email',
	m.email_enviado_em
from pncp.contratacoes_mensagens_mencoes m
join adm.grupos_permissoes gp on (gp.conta_id = m.conta_id)
join adm.grupos_permissoes_usuarios gpu on (gpu.grupo_permissao_id = gp.id)
where m.email_enviado_em is not null
on conflict do nothing;

drop index pncp.ix_contratacoes_mensagens_mencoes_pendentes;

alter table pncp.contratacoes_mensagens_mencoes
    drop column email_enviado_em;

alter table audit.pncp_contratacoes_mensagens_mencoes
    drop column email_enviado_em;
