-- Corrige audit.adm_usuarios.senha para aceitar NULL, alinhando com adm.usuarios.senha
-- (nullable desde o login com Google, onde usuários podem não ter senha local).
alter table audit.adm_usuarios alter column senha drop not null;
