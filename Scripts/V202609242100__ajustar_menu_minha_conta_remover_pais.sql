/******************************************************************************************
 * Ajuste de menu — módulo 97 (Radar de Licitações)
 *
 * Remove os menus pais "Configurações" e "Cadastros", promovendo seus filhos a menus de
 * topo (menu_pai_id null), e adiciona "Minha Conta" (rota minha-conta), que só existia no
 * banco local (nunca foi versionado).
 *
 * Cuidado: menus_menu_pai_id_fkey não tem ON DELETE CASCADE, então os filhos precisam ser
 * reparentados (por descrição do pai, não por id — os ids variam entre bases) antes do
 * delete dos pais. O reparenting também cobre a base local, onde "Minha Conta" já existe
 * como filho de "Configurações"; nas demais bases, o insert abaixo é quem cria o menu.
 */

update adm.menus filho
   set menu_pai_id = null
  from adm.menus pai
 where filho.menu_pai_id = pai.id
   and pai.modulo_id = 97
   and pai.menu_pai_id is null
   and pai.descricao in ('Configurações', 'Cadastros');

insert into adm.menus (modulo_id, descricao, rota)
values (97, 'Minha Conta', 'minha-conta')
on conflict (modulo_id, menu_pai_id, descricao) do nothing;

delete from adm.menus
 where modulo_id = 97
   and menu_pai_id is null
   and descricao in ('Configurações', 'Cadastros');
