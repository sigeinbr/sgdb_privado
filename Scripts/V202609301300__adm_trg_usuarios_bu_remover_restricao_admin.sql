/******************************************************************************************
 * Function: adm.trg_usuarios_bu (create or replace)
 *
 * Remove a regra herdada do Sigein que impedia o sgisis de alterar um usuário quando o
 * updated_by não era administrador (módulo 1) de todas as contas desse usuário. Aqui
 * autorização é responsabilidade da aplicação, e a regra bloqueava fluxos legítimos —
 * ex.: ao cadastrar um telefone pendente em outro usuário, a API limpa o telefone do
 * outro usuário com updated_by = usuário atual.
 */
create or replace function adm.trg_usuarios_bu()
 returns trigger
 language plpgsql
as $function$
begin
  if new.login <> old.login then
    raise exception 'Não é permitido alterar o login.';
  end if;

  if new.login like 'sgitec%' then
    raise exception 'Não é permitido criar usuários sgitecs.';
  end if;

  if new.email <> old.email then
    new.is_verificado = false;
  end if;

  if new.telefone is distinct from old.telefone then
    new.whatsapp_verificado = false;
  end if;

  if new.deleted_by is not null then
    if exists(select * from adm.grupos_permissoes_usuarios where usuario_login = new.login) then
      raise exception 'Não é permitido excluir usuários com grupos de permissões vinculados.';
    end if;
  end if;
  return new;
end;
$function$;
