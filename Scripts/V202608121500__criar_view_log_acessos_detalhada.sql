/**
 * VIEW: audit.view_log_acessos_detalhada
 *
 * Enriquece audit.log_acessos com navegador/SO (via audit.func_parse_user_agent) e a
 * descrição do módulo, para uso em relatórios de auditoria de acesso.
 *
 * Copiado de ../sgbd (Scripts/V202510221400.sql).
 */
create or replace view audit.view_log_acessos_detalhada
as select la.id,
    la.usuario_login,
    la.dh_acesso,
    la.modulo_id,
    la.rota,
    la.ip,
    la.context,
    la.user_agent,
    pug.browser_name as browser,
    pug.os_name as os,
    (select descricao from adm.modulos where id = la.modulo_id) as modulo_descricao
   from audit.log_acessos la,
    lateral audit.func_parse_user_agent(la.user_agent) pug(browser_name, os_name);

grant select on audit.view_log_acessos_detalhada to sgisis;
grant select on audit.view_log_acessos_detalhada to sgitec;
grant select on audit.view_log_acessos_detalhada to consulta;
