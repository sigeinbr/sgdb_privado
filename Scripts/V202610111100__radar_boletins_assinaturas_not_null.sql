/******************************************************************************************
 * Radar de Licitações - boletins inteligentes (Bloco 2 - somente APÓS o deploy do código novo)
 *
 * adm.assinaturas.limite_boletins passa a NOT NULL e assinaturas_proximo_chk inclui
 * proximo_limite_boletins. Antes de aplicar, recarrega as linhas gravadas pelo código
 * antigo entre o Bloco 1 e o deploy (limite_boletins nulo / proximo_* sem o boletim).
 */
update adm.assinaturas
   set limite_boletins = limite_contratacoes
 where limite_boletins is null;

update adm.assinaturas
   set proximo_limite_boletins = proximo_limite_contratacoes
 where (proximo_limite_boletins is null) <> (proximo_limite_contratacoes is null);

update adm.cobrancas
   set limite_boletins = limite_contratacoes
 where limite_boletins is null;

alter table adm.assinaturas alter column limite_boletins set not null;

alter table adm.assinaturas drop constraint assinaturas_proximo_chk;
alter table adm.assinaturas add constraint assinaturas_proximo_chk check (
	(proximo_plano_codigo is null and proximo_limite_contratacoes is null and proximo_limite_empresas is null
	 and proximo_limite_usuarios is null and proximo_limite_boletins is null and proximo_valor_mensal is null)
	or
	(proximo_plano_codigo is not null and proximo_limite_contratacoes is not null and proximo_limite_empresas is not null
	 and proximo_limite_usuarios is not null and proximo_limite_boletins is not null and proximo_valor_mensal is not null)
);
