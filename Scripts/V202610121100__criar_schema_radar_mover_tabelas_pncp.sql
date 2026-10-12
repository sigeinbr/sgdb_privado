/******************************************************************************************
 * Radar de Licitações — schema radar separado do espelho pncp
 *
 * O schema pncp deveria conter só o espelho global dos dados públicos (PNCP e Comprasnet),
 * sem divisão por conta/empresa, mas acumulou as tabelas de negócio do Radar de Licitações
 * (módulo 97). Este script move essas tabelas para o novo schema radar.
 *
 * Ficam em pncp: orgaos, orgaos_unidades, contratacoes, contratacoes_itens,
 * contratacoes_itens_resultados, contratacoes_arquivos, contratacoes_mensagens.
 *
 * 1. Cria o schema radar.
 * 2. Move as 11 tabelas do radar (set schema leva índices, constraints, FKs, triggers, grants
 *    e sequences owned by) e renomeia as tabelas audit correspondentes de audit.pncp_X para
 *    audit.radar_X — obrigatório, pois audit.func_audit_after() resolve a tabela audit por
 *    TG_TABLE_SCHEMA || '_' || TG_TABLE_NAME.
 * 3. Renomeia usuarios_preferencas_notificacao -> preferencias_notificacoes.
 * 4. Renomeia os espelhos audit congelados (tabelas de negócio já dropadas) para audit.radar_*.
 * 5. Restaura pncp.contratacoes_mensagens.dados_json (removido em V202610021300).
 * 6. Atualiza comentários.
 *
 * Deploy coordenado com o radar_licitacoes: a versão anterior do código referencia pncp.X
 * para as tabelas movidas e não grava dados_json (agora NOT NULL).
 */

/******************************************************************************************
 * 1. Schema radar
 */
create schema radar;

comment on schema radar is
  'Tabelas de negócio do Radar de Licitações (módulo 97): empresas monitoradas, boletins, '
  'notificações e preferências. Os dados públicos de contratações ficam no schema pncp.';

grant usage on schema radar to sgisis;
grant usage on schema radar to sgitec;
grant usage on schema radar to consulta;

/******************************************************************************************
 * 2. Mover tabelas para radar + renomear tabelas e índices audit
 */
alter table pncp.empresas set schema radar;
alter table audit.pncp_empresas rename to radar_empresas;
alter index audit.pncp_empresas_idx1 rename to radar_empresas_idx1;
alter index audit.pncp_empresas_idx2 rename to radar_empresas_idx2;

alter table pncp.empresas_usuarios set schema radar;
alter table audit.pncp_empresas_usuarios rename to radar_empresas_usuarios;
alter index audit.pncp_empresas_usuarios_idx1 rename to radar_empresas_usuarios_idx1;
alter index audit.pncp_empresas_usuarios_idx2 rename to radar_empresas_usuarios_idx2;

alter table pncp.empresas_contratacoes set schema radar;
alter table audit.pncp_empresas_contratacoes rename to radar_empresas_contratacoes;
alter index audit.pncp_empresas_contratacoes_idx1 rename to radar_empresas_contratacoes_idx1;
alter index audit.pncp_empresas_contratacoes_idx2 rename to radar_empresas_contratacoes_idx2;

alter table pncp.boletins set schema radar;
alter table audit.pncp_boletins rename to radar_boletins;
alter index audit.pncp_boletins_idx1 rename to radar_boletins_idx1;
alter index audit.pncp_boletins_idx2 rename to radar_boletins_idx2;

alter table pncp.boletins_edicoes set schema radar;
alter table audit.pncp_boletins_edicoes rename to radar_boletins_edicoes;
alter index audit.pncp_boletins_edicoes_idx1 rename to radar_boletins_edicoes_idx1;
alter index audit.pncp_boletins_edicoes_idx2 rename to radar_boletins_edicoes_idx2;

alter table pncp.boletins_edicoes_itens set schema radar;
alter table audit.pncp_boletins_edicoes_itens rename to radar_boletins_edicoes_itens;
alter index audit.pncp_boletins_edicoes_itens_idx1 rename to radar_boletins_edicoes_itens_idx1;
alter index audit.pncp_boletins_edicoes_itens_idx2 rename to radar_boletins_edicoes_itens_idx2;

alter table pncp.boletins_notificacoes set schema radar;
alter table audit.pncp_boletins_notificacoes rename to radar_boletins_notificacoes;
alter index audit.pncp_boletins_notificacoes_idx1 rename to radar_boletins_notificacoes_idx1;
alter index audit.pncp_boletins_notificacoes_idx2 rename to radar_boletins_notificacoes_idx2;

alter table pncp.boletins_visualizacoes set schema radar;
alter table audit.pncp_boletins_visualizacoes rename to radar_boletins_visualizacoes;
alter index audit.pncp_boletins_visualizacoes_idx1 rename to radar_boletins_visualizacoes_idx1;
alter index audit.pncp_boletins_visualizacoes_idx2 rename to radar_boletins_visualizacoes_idx2;

alter table pncp.notificacoes_enviadas set schema radar;
alter table audit.pncp_notificacoes_enviadas rename to radar_notificacoes_enviadas;
alter index audit.pncp_notificacoes_enviadas_idx1 rename to radar_notificacoes_enviadas_idx1;
alter index audit.pncp_notificacoes_enviadas_idx2 rename to radar_notificacoes_enviadas_idx2;

alter table pncp.alertas_operacionais set schema radar;
alter table audit.pncp_alertas_operacionais rename to radar_alertas_operacionais;
alter index audit.pncp_alertas_operacionais_idx1 rename to radar_alertas_operacionais_idx1;
alter index audit.pncp_alertas_operacionais_idx2 rename to radar_alertas_operacionais_idx2;

/******************************************************************************************
 * 3. usuarios_preferencas_notificacao -> radar.preferencias_notificacoes
 */
alter table pncp.usuarios_preferencas_notificacao set schema radar;
alter table radar.usuarios_preferencas_notificacao rename to preferencias_notificacoes;

alter table radar.preferencias_notificacoes
  rename constraint usuarios_preferencas_notificacao_pkey to preferencias_notificacoes_pkey;
alter table radar.preferencias_notificacoes
  rename constraint usuarios_preferencas_notificacao_canal_chk to preferencias_notificacoes_canal_chk;
alter table radar.preferencias_notificacoes
  rename constraint usuarios_preferencas_notificacao_tipo_sinal_chk to preferencias_notificacoes_tipo_sinal_chk;
alter table radar.preferencias_notificacoes
  rename constraint usuarios_preferencas_notificacao_usuario_login_fkey to preferencias_notificacoes_usuario_login_fkey;

alter table audit.pncp_usuarios_preferencas_notificacao rename to radar_preferencias_notificacoes;
alter index audit.pncp_usuarios_preferencas_notificacao_idx1 rename to radar_preferencias_notificacoes_idx1;
alter index audit.pncp_usuarios_preferencas_notificacao_idx2 rename to radar_preferencias_notificacoes_idx2;

/******************************************************************************************
 * 4. Espelhos audit congelados (tabelas de negócio do radar já dropadas)
 */
alter table audit.pncp_contas_contratacoes rename to radar_contas_contratacoes;
alter index audit.pncp_contas_contratacoes_idx1 rename to radar_contas_contratacoes_idx1;
alter index audit.pncp_contas_contratacoes_idx2 rename to radar_contas_contratacoes_idx2;

alter table audit.pncp_empresas_mencoes rename to radar_empresas_mencoes;
alter index audit.pncp_empresas_mencoes_idx1 rename to radar_empresas_mencoes_idx1;
alter index audit.pncp_empresas_mencoes_idx2 rename to radar_empresas_mencoes_idx2;

alter table audit.pncp_mencoes_notificacoes_enviadas rename to radar_mencoes_notificacoes_enviadas;
alter index audit.pncp_mencoes_notificacoes_enviadas_idx1 rename to radar_mencoes_notificacoes_enviadas_idx1;
alter index audit.pncp_mencoes_notificacoes_enviadas_idx2 rename to radar_mencoes_notificacoes_enviadas_idx2;

alter table audit.pncp_contratacoes_mensagens_mencoes rename to radar_contratacoes_mensagens_mencoes;
alter index audit.pncp_contratacoes_mensagens_mencoes_idx1 rename to radar_contratacoes_mensagens_mencoes_idx1;
alter index audit.pncp_contratacoes_mensagens_mencoes_idx2 rename to radar_contratacoes_mensagens_mencoes_idx2;

/******************************************************************************************
 * 5. pncp.contratacoes_mensagens.dados_json
 *
 * O payload removido em V202610021300 não existe mais (nem na audit): as linhas atuais
 * recebem '{}'. O default é retirado em seguida para que todo insert novo grave o payload.
 */
alter table pncp.contratacoes_mensagens add column dados_json jsonb not null default '{}'::jsonb;
alter table pncp.contratacoes_mensagens alter column dados_json drop default;

comment on column pncp.contratacoes_mensagens.dados_json is
  'Payload bruto da mensagem na origem. Linhas anteriores a V202610121100 contêm ''{}''.';

alter table audit.pncp_contratacoes_mensagens add column dados_json jsonb null;

/******************************************************************************************
 * 6. Comentários
 */
comment on schema pncp is
  'Espelho global dos dados públicos de contratações (PNCP e Comprasnet). Sem divisão por '
  'conta/empresa e sem regras de negócio — as tabelas do Radar de Licitações ficam no schema radar.';

comment on table pncp.contratacoes is
  'Referência local da contratação PNCP. O dado completo do PNCP está no banco pncp.';
