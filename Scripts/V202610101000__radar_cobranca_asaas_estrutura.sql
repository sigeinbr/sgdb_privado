/******************************************************************************************
 * Radar de Licitacoes - cobranca pelo Asaas (Bloco 1 - estrutura aditiva)
 *
 * - adm.cobrancas deixa de ser imutavel: nasce 'pendente' e muda situacao/colunas de controle
 * - adm.assinaturas: gateway_assinatura_id (pagamento automatico no cartao)
 * - adm.contas: asaas_customer_id
 * - adm.asaas_eventos: eventos do webhook (idempotencia e reprocessamento)
 *
 * A coluna adm.cobrancas.operacao entra NULLABLE; o NOT NULL vem em migration posterior,
 * aplicada somente depois do deploy do codigo novo (Bloco 2).
 */

/******************************************************************************************
 * adm.cobrancas - colunas novas
 */
alter table adm.cobrancas add column operacao text null;
alter table adm.cobrancas add column destino_valor_mensal numeric(12,2) null;
alter table adm.cobrancas add column destino_dia_vencimento smallint null;
alter table adm.cobrancas add column vence_em date null;
alter table adm.cobrancas add column link_pagamento text null;
alter table adm.cobrancas add column gateway_assinatura_id text null;
alter table adm.cobrancas add column aplicada_em timestamptz null;
alter table adm.cobrancas add column cancelada_em timestamptz null;

alter table adm.cobrancas add constraint cobrancas_operacao_chk
	check (operacao in ('novo_ciclo', 'renovacao', 'upgrade', 'troca_dia'));
alter table adm.cobrancas add constraint cobrancas_destino_dia_vencimento_chk
	check (destino_dia_vencimento between 1 and 31);

-- Linhas existentes: operacao a partir de motivo
update adm.cobrancas
   set operacao = case motivo
                    when 'ciclo' then 'novo_ciclo'
                    when 'upgrade_prorata' then 'upgrade'
                    when 'troca_vencimento_prorata' then 'troca_dia'
                  end
 where operacao is null;

-- situacao passa a aceitar 'estornada'
alter table adm.cobrancas drop constraint cobrancas_situacao_chk;
alter table adm.cobrancas add constraint cobrancas_situacao_chk
	check (situacao in ('confirmada_sem_gateway', 'pendente', 'paga', 'cancelada', 'estornada'));

-- Um payment do Asaas corresponde a uma unica linha
create unique index cobrancas_gateway_id_ukey on adm.cobrancas(gateway_id) where gateway_id is not null;

-- No maximo uma cobranca avulsa pendente por conta (parcelas do cartao automatico nao entram)
create unique index cobrancas_avulsa_pendente_ukey on adm.cobrancas(conta_id)
	where situacao = 'pendente' and gateway_assinatura_id is null;

-- Job de reconciliacao varre as pendentes
create index cobrancas_pendentes_idx on adm.cobrancas(situacao) where situacao = 'pendente';

/******************************************************************************************
 * audit.adm_cobrancas - espelho das colunas novas (sem constraints; operacao aceita NULL)
 */
alter table audit.adm_cobrancas add column operacao text null;
alter table audit.adm_cobrancas add column destino_valor_mensal numeric(12,2) null;
alter table audit.adm_cobrancas add column destino_dia_vencimento smallint null;
alter table audit.adm_cobrancas add column vence_em date null;
alter table audit.adm_cobrancas add column link_pagamento text null;
alter table audit.adm_cobrancas add column gateway_assinatura_id text null;
alter table audit.adm_cobrancas add column aplicada_em timestamptz null;
alter table audit.adm_cobrancas add column cancelada_em timestamptz null;

/******************************************************************************************
 * adm.assinaturas - pagamento automatico no cartao
 */
alter table adm.assinaturas add column gateway_assinatura_id text null;
alter table adm.assinaturas add constraint assinaturas_gateway_assinatura_id_ukey unique (gateway_assinatura_id);

alter table audit.adm_assinaturas add column gateway_assinatura_id text null;

/******************************************************************************************
 * adm.contas - customer no Asaas
 */
alter table adm.contas add column asaas_customer_id text null;
alter table adm.contas add constraint contas_asaas_customer_id_ukey unique (asaas_customer_id);

alter table audit.adm_contas add column asaas_customer_id text null;

/******************************************************************************************
 * TABELA: adm.asaas_eventos
 */
create table adm.asaas_eventos(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	id text primary key,
	evento text not null,
	payment_id text null,
	subscription_id text null,
	payload jsonb not null,
	recebido_em timestamptz default now() not null,
	processado_em timestamptz null,
	tentativas integer default 0 not null,
	ultimo_erro text null
);

create index asaas_eventos_pendentes_idx on adm.asaas_eventos(recebido_em) where processado_em is null;

grant select, insert, update on adm.asaas_eventos to sgisis;
grant select, insert, update on adm.asaas_eventos to sgitec;
grant select on adm.asaas_eventos to consulta;

/******************************************************************************************
 * TABELA: audit.adm_asaas_eventos
 */
create table audit.adm_asaas_eventos (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	id text not null,
	evento text not null,
	payment_id text null,
	subscription_id text null,
	payload jsonb not null,
	recebido_em timestamptz not null,
	processado_em timestamptz null,
	tentativas integer not null,
	ultimo_erro text null
);

create index adm_asaas_eventos_idx1 on audit.adm_asaas_eventos(dh_audit,oper_audit,usuario_audit);
create index adm_asaas_eventos_idx2 on audit.adm_asaas_eventos(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.adm_asaas_eventos to sgisis;
grant select on audit.adm_asaas_eventos to sgitec;
grant select on audit.adm_asaas_eventos to consulta;

/******************************************************************************************
 * Criacao das triggers para audit
 */
create trigger audit_bi before insert on adm.asaas_eventos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.asaas_eventos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.asaas_eventos for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.asaas_eventos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.asaas_eventos for each row execute function audit.func_audit_after();
