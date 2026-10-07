/******************************************************************************************
 * Seed: adm.menus — módulo 97 (Radar de Licitações)
 *
 * Adiciona o menu de topo "Pesquisas (Beta)" (rota pesquisa) e redefine a ordem de
 * exibição dos menus de topo: 1 Minha Conta, 2 Pesquisas, 3 Contratações, 4 Mensagens.
 * Vincula o novo menu aos grupos "Administrador" e "Usuário" do módulo 97.
 */
insert into adm.menus (modulo_id, descricao, rota)
values (97, 'Pesquisas (Beta)', 'pesquisa')
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
   and descricao = 'Pesquisas (Beta)';

update adm.menus
   set ordem = 3
 where modulo_id = 97
   and menu_pai_id is null
   and descricao = 'Contratações';

update adm.menus
   set ordem = 4
 where modulo_id = 97
   and menu_pai_id is null
   and descricao = 'Mensagens';

-- Vincula os menus "Pesquisas (Beta)" e "Mensagens" ao grupo "Usuário" (grupos existentes)
insert into adm.grupos_permissoes_menus (grupo_permissao_id, menu_id)
select gp.id, m.id
  from adm.grupos_permissoes gp
  join adm.menus m on (m.modulo_id = gp.modulo_id and m.rota in ('pesquisa', 'mencoes'))
 where gp.modulo_id = 97
   and gp.descricao = 'Usuário'
on conflict (grupo_permissao_id, menu_id) do nothing;
