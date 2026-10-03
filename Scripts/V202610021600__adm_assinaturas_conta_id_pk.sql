-- Reverte decisao tomada em V202610021400: adm.assinaturas eh o ESTADO ATUAL
-- da assinatura da conta (uma linha por conta, atualizada a cada ciclo/troca
-- de plano), nao um historico com N linhas. conta_id volta a ser a PK, sem
-- id serial -- o pedido original ja estava correto nisso.

alter table adm.assinaturas drop constraint assinaturas_conta_vigencia_ukey;
alter table adm.assinaturas drop constraint assinaturas_pkey;
alter table adm.assinaturas drop column id;
alter table adm.assinaturas add constraint assinaturas_pkey primary key (conta_id);

alter table audit.adm_assinaturas drop column id;
