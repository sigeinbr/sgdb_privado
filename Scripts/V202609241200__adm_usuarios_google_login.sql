alter table adm.usuarios
    add column google_id varchar(255) null;

alter table adm.usuarios
    add constraint usuarios_google_id_ukey unique (google_id);

alter table adm.usuarios
    alter column senha drop not null;

alter table audit.adm_usuarios
    add column google_id varchar(255) null;

alter type adm.enum_tipo_token rename value 'criacao_conta' to 'criacao_usuario';

-- Invalida cadastros pendentes com o shape antigo de parametros, incompatível com o novo
-- confirmarCadastro.
update adm.tokens set ativo = false
where tipo = 'criacao_usuario' and ativo = true;
