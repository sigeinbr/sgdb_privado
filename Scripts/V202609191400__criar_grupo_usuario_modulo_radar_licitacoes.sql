/******************************************************************************************
 * Procedure: adm.proc_gerar_grupos_permissoes_padroes
 *
 * Ajuste: o módulo 97 (Radar de Licitações) passa a receber o grupo "Usuário" em vez de
 * "Consultas e Relatórios" — mesmo acesso (todas as consultas e relatórios), mas também
 * vinculado ao menu "Contratações" (rota 'contratacoes'), já que esse grupo não tem
 * todos_menus = true.
 */
create or replace procedure adm.proc_gerar_grupos_permissoes_padroes(in p_conta integer, in p_modulo integer)
 language plpgsql
as $procedure$
declare
  v_grupo   varchar(100);
  v_usuario varchar(100);
  r         record;
begin
  if exists(select * from adm.contas where id = p_conta) then
    if exists(select * from adm.modulos where id = p_modulo) then

      if p_modulo = 1 then
        if exists(select * from adm.contas_modulos where conta_id = p_conta and modulo_id = p_modulo) then
          v_grupo = 'Administrador';
          if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
            insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
            values (v_grupo, p_conta, p_modulo, true, true, true);
          end if;

          v_usuario = 'admin';
          if exists(select * from adm.usuarios where login = v_usuario) then
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end if;

          for r in
            select gpu.usuario_login
            from adm.grupos_permissoes gp
            join adm.grupos_permissoes_usuarios gpu on (gp.id = gpu.grupo_permissao_id)
            where gp.descricao = 'Administrador' and gp.modulo_id = 1 and gp.conta_id = p_conta
          loop
            v_usuario = r.usuario_login;
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end loop;
        end if;
      end if;

      if p_modulo <> 1 then
        if exists(select * from adm.contas_modulos where conta_id = p_conta and modulo_id = p_modulo) then
          v_grupo = 'Administrador';
          if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
            insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
            values (v_grupo, p_conta, p_modulo, true, true, true);
          end if;

          for r in
            select gpu.usuario_login
            from adm.grupos_permissoes gp
            join adm.grupos_permissoes_usuarios gpu on (gp.id = gpu.grupo_permissao_id)
            where gp.descricao = 'Administrador' and gp.modulo_id = 1 and gp.conta_id = p_conta
          loop
            v_usuario = r.usuario_login;
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end loop;

          if p_modulo = 97 then
            v_grupo = 'Usuário';
            if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
              insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
              values (v_grupo, p_conta, p_modulo, false, true, true);
            end if;

            insert into adm.grupos_permissoes_menus (grupo_permissao_id, menu_id)
            select gp.id, m.id
              from adm.grupos_permissoes gp
              join adm.menus m on (m.modulo_id = gp.modulo_id and m.rota = 'contratacoes')
             where gp.conta_id = p_conta and gp.descricao = v_grupo and gp.modulo_id = p_modulo
            on conflict (grupo_permissao_id, menu_id) do nothing;
          else
            v_grupo = 'Consultas e Relatórios';
            if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
              insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
              values (v_grupo, p_conta, p_modulo, false, true, true);
            end if;
          end if;
        end if;
      end if;

    end if;
  end if;
end;
$procedure$;


/******************************************************************************************
 * Backfill: contas que já habilitaram o módulo 97 antes deste ajuste ganham o grupo
 * "Usuário" (renomeado a partir de "Consultas e Relatórios") e o vínculo com o menu
 * "Contratações".
 */
update adm.grupos_permissoes
   set descricao = 'Usuário'
 where modulo_id = 97
   and descricao = 'Consultas e Relatórios';

insert into adm.grupos_permissoes_menus (grupo_permissao_id, menu_id)
select gp.id, m.id
  from adm.grupos_permissoes gp
  join adm.menus m on (m.modulo_id = gp.modulo_id and m.rota = 'contratacoes')
 where gp.modulo_id = 97
   and gp.descricao = 'Usuário'
on conflict (grupo_permissao_id, menu_id) do nothing;
