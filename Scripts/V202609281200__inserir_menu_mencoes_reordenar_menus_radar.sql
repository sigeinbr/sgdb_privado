/******************************************************************************************
 * Seed/ajuste: adm.menus — módulo 97 (Radar de Licitações)
 *
 * Adiciona o menu de topo "Menções" (rota mencoes) e define a ordem de exibição dos
 * menus de topo: 1 Minha Conta, 2 Contratações, 3 Menções.
 */
insert into adm.menus (modulo_id, descricao, rota)
values (97, 'Menções', 'mencoes')
on conflict (modulo_id, menu_pai_id, descricao) do nothing;

update adm.menus
   set ordem = 1
 where modulo_id = 97
   and menu_pai_id is null
   and descricao = 'Minha Conta';

update adm.menus
   set ordem = 2
 where modulo_id = 97
   and menu_pai_id is null
   and descricao = 'Contratações';

update adm.menus
   set ordem = 3
 where modulo_id = 97
   and menu_pai_id is null
   and descricao = 'Menções';
