alter table adm.usuarios
    add column whatsapp_verificado boolean not null default false;

alter table audit.adm_usuarios
    add column whatsapp_verificado boolean;

/******************************************************************************************
 * Function: adm.trg_usuarios_bu (create or replace)
 *
 * Adiciona a regra de invalidar a verificação de WhatsApp ao trocar o telefone, no mesmo
 * padrão já usado para e-mail/is_verificado.
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

  if current_user = 'sgisis' and new.login <> new.updated_by then
    if exists(
      select gp.conta_id
      from adm.grupos_permissoes_usuarios gpu
      join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
      where gpu.usuario_login = new.login
        and gp.conta_id not in (
          select gp.conta_id
          from adm.grupos_permissoes_usuarios gpu
          join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
          where gpu.usuario_login = new.updated_by
            and gp.modulo_id = 1
        )
    ) then
      raise exception 'O usuário % não pode editar o usuário % pois não tem acesso de administrador a todas as contas do mesmo.', new.updated_by, new.login;
    end if;
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
