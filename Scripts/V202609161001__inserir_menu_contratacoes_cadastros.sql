/******************************************************************************************
 * Seed: adm.menus — módulo 97 (Radar de Licitações)
 *
 * Item "Contratações" (rota contratacoes) dentro do menu pai "Cadastros".
 */
insert into adm.menus (modulo_id, descricao)
values (97, 'Cadastros')
on conflict (modulo_id, menu_pai_id, descricao) do nothing;

insert into adm.menus (modulo_id, menu_pai_id, descricao, rota)
select 97, m.id, 'Contratações', 'contratacoes'
  from adm.menus m
 where m.modulo_id = 97
   and m.menu_pai_id is null
   and m.descricao = 'Cadastros'
on conflict (modulo_id, menu_pai_id, descricao) do nothing;
