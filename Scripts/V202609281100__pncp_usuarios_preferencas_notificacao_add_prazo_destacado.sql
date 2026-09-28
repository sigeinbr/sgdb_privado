/******************************************************************************************
 * pncp.usuarios_preferencas_notificacao: novo valor de tipo_sinal 'prazo_destacado'
 *
 * Existe só como dimensão de preferência, não como sinal de detecção — não altera
 * pncp.contratacoes_mensagens_mencoes.tipo_sinal (que continua destinatario/cnpj_texto/
 * nome_texto). Quando uma menção tiver prazo_em preenchido, o envio passa a respeitar
 * também a preferência 'prazo_destacado', além da preferência do seu tipo_sinal de
 * origem. tipo_sinal é varchar com check, não enum de banco — só precisa ampliar o check.
 */
alter table pncp.usuarios_preferencas_notificacao
    drop constraint usuarios_preferencas_notificacao_tipo_sinal_chk;

alter table pncp.usuarios_preferencas_notificacao
    add constraint usuarios_preferencas_notificacao_tipo_sinal_chk
    check (tipo_sinal in ('destinatario','cnpj_texto','nome_texto','prazo_destacado'));
