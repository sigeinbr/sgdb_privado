/******************************************************************************************
 * pncp.contratacoes_mensagens_mencoes: colunas de prazo extraído
 *
 * Populadas só quando tipo_sinal = 'destinatario' e o texto casar com algum dos padrões
 * de extração de prazo; nulas nos demais casos. prazo_trecho_fonte guarda o trecho
 * original usado para exibir "baseado em: ..." quando prazo_confianca = 'estimada'.
 */
alter table pncp.contratacoes_mensagens_mencoes
    add column prazo_em timestamp(0) null;

alter table pncp.contratacoes_mensagens_mencoes
    add column prazo_confianca varchar(10) null;

alter table pncp.contratacoes_mensagens_mencoes
    add column prazo_trecho_fonte text null;

alter table pncp.contratacoes_mensagens_mencoes
    add constraint contratacoes_mensagens_mencoes_prazo_confianca_chk
    check (prazo_confianca in ('alta','estimada'));

alter table audit.pncp_contratacoes_mensagens_mencoes
    add column prazo_em timestamp(0);

alter table audit.pncp_contratacoes_mensagens_mencoes
    add column prazo_confianca varchar(10);

alter table audit.pncp_contratacoes_mensagens_mencoes
    add column prazo_trecho_fonte text;
