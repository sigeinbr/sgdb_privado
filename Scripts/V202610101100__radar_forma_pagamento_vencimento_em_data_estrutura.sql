/******************************************************************************************
 * Radar de Licitacoes - forma de pagamento recorrente e vencimento em data (Bloco 1)
 *
 * O vencimento da licenca deixa de ser um instante (assinaturas.vigente_ate = 00:00
 * America/Sao_Paulo do primeiro dia do periodo seguinte) e passa a ser uma data: o ULTIMO
 * dia de uso do periodo (assinaturas.vencimento). dia_vencimento passa a ser o dia desse
 * ultimo dia (antes era o dia do inicio do periodo): dia - 1, e 1 -> 31.
 * forma_pagamento (pix, boleto, cartao) vira atributo da assinatura e de cada cobranca.
 *
 * Este Bloco 1 e aditivo e DEVE ser aplicado junto com o deploy do codigo novo.
 * As colunas vigente_ate, ciclo_inicio e motivo ficam NULLABLE aqui e so saem no Bloco 2
 * (migration posterior, aplicada somente depois do deploy), assim como o NOT NULL de
 * adm.cobrancas.operacao.
 *
 * Esta migration roda uma unica vez (Flyway), portanto a conversao de dia_vencimento nao
 * e reaplicada.
 */

/******************************************************************************************
 * adm.assinaturas
 */
alter table adm.assinaturas add column vencimento date null;
alter table adm.assinaturas add column forma_pagamento text not null default 'pix';

alter table audit.adm_assinaturas add column vencimento date null;
alter table audit.adm_assinaturas add column forma_pagamento text null;

alter table adm.assinaturas add constraint assinaturas_forma_pagamento_chk
	check (forma_pagamento in ('pix', 'boleto', 'cartao'));

update adm.assinaturas
   set vencimento = (vigente_ate at time zone 'America/Sao_Paulo')::date - 1,
       dia_vencimento = case when dia_vencimento = 1 then 31 else dia_vencimento - 1 end,
       forma_pagamento = case when gateway_assinatura_id is not null then 'cartao' else 'pix' end;

alter table adm.assinaturas alter column vencimento set not null;

-- Pipeline de mencoes filtra contas vigentes por vencimento >= hoje (America/Sao_Paulo)
create index assinaturas_vencimento_idx on adm.assinaturas (vencimento);

-- O codigo novo nao grava mais estas colunas (somem no Bloco 2). Na audit tambem, senao o
-- espelho das linhas novas falharia.
alter table adm.assinaturas alter column vigente_ate drop not null;
alter table adm.assinaturas alter column ciclo_inicio drop not null;
alter table audit.adm_assinaturas alter column vigente_ate drop not null;
alter table audit.adm_assinaturas alter column ciclo_inicio drop not null;

/******************************************************************************************
 * adm.cobrancas
 */
alter table adm.cobrancas add column forma_pagamento text null;
alter table audit.adm_cobrancas add column forma_pagamento text null;

alter table adm.cobrancas add constraint cobrancas_forma_pagamento_chk
	check (forma_pagamento in ('pix', 'boleto', 'cartao'));

-- Somente pendentes (ainda serao aplicadas pelo codigo novo); as demais ficam como historico
update adm.cobrancas
   set destino_dia_vencimento = case when destino_dia_vencimento = 1 then 31 else destino_dia_vencimento - 1 end
 where situacao = 'pendente'
   and destino_dia_vencimento is not null;

alter table adm.cobrancas alter column motivo drop not null;
alter table audit.adm_cobrancas alter column motivo drop not null;

/******************************************************************************************
 * adm.avisos_vencimento_enviados
 */
alter table adm.avisos_vencimento_enviados add column vencimento date null;
alter table audit.adm_avisos_vencimento_enviados add column vencimento date null;

update adm.avisos_vencimento_enviados
   set vencimento = (vigente_ate at time zone 'America/Sao_Paulo')::date - 1;

alter table adm.avisos_vencimento_enviados alter column vencimento set not null;

-- A troca de PK falha (abortando a migration) se houver colisao em (conta_id, vencimento, tipo)
alter table adm.avisos_vencimento_enviados drop constraint avisos_vencimento_enviados_pkey;
alter table adm.avisos_vencimento_enviados
	add constraint avisos_vencimento_enviados_pkey primary key (conta_id, vencimento, tipo);

alter table adm.avisos_vencimento_enviados alter column vigente_ate drop not null;
alter table audit.adm_avisos_vencimento_enviados alter column vigente_ate drop not null;
