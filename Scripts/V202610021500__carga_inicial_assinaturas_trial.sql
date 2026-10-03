-- Carga inicial de assinatura trial para toda conta que ainda nao tem uma --
-- idempotente: a tabela temporaria abaixo so pega contas sem linha em
-- adm.assinaturas, entao reaplicar (hipoteticamente) nao duplica nada --
-- os tres inserts dependem so dela, sem precisar de ON CONFLICT.

create temporary table tmp_novas_assinaturas on commit drop as
select
	c.id as conta_id,
	c.cnpj,
	c.cpf,
	c.email_contato,
	(now() at time zone 'America/Sao_Paulo')::date as ciclo_inicio,
	(((now() at time zone 'America/Sao_Paulo')::date + interval '1 month') at time zone 'America/Sao_Paulo') as vigente_ate
from adm.contas c
where not exists (select 1 from adm.assinaturas a where a.conta_id = c.id);

insert into adm.assinaturas (conta_id, plano_codigo, limite_contratacoes, limite_empresas, limite_usuarios, valor_mensal, dia_vencimento, ciclo_inicio, vigente_ate)
select
	conta_id,
	'trial',
	5, 1, 1,
	0.00,
	extract(day from ciclo_inicio)::smallint,
	ciclo_inicio,
	vigente_ate
from tmp_novas_assinaturas;

insert into adm.cobrancas (conta_id, motivo, plano_codigo, limite_contratacoes, limite_empresas, limite_usuarios, periodo_inicio, periodo_fim, valor, situacao, confirmada_em)
select
	conta_id,
	'ciclo',
	'trial',
	5, 1, 1,
	ciclo_inicio,
	(vigente_ate at time zone 'America/Sao_Paulo')::date - 1,
	0.00,
	'confirmada_sem_gateway',
	now()
from tmp_novas_assinaturas;

insert into adm.trials_concedidos (conta_id, documento, email, usuario_login)
select
	t.conta_id,
	coalesce(t.cnpj, t.cpf),
	lower(t.email_contato),
	gpu.usuario_login
from tmp_novas_assinaturas t
	join adm.grupos_permissoes gp on (gp.conta_id = t.conta_id and gp.modulo_id = 97 and gp.descricao = 'Administrador')
	join adm.grupos_permissoes_usuarios gpu on (gpu.grupo_permissao_id = gp.id);

-- Conferencia manual pos-deploy (nao faz parte da migration):
-- select (select count(*) from adm.assinaturas) = (select count(*) from adm.contas);
-- select (select count(*) from adm.cobrancas) = (select count(*) from adm.contas);
