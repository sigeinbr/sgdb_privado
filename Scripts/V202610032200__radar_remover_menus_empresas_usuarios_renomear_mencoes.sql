/******************************************************************************************
 * Radar de Licitações (módulo 97) — ajuste de menus
 *
 * Remove os menus de topo "Empresas" (rota empresas) e "Usuários" (rota usuarios); os
 * vínculos em adm.grupos_permissoes_menus caem em cascata (on delete cascade).
 * Renomeia o menu "Menções" para "Mensagens" — a rota 'mencoes' é mantida para não
 * quebrar a aplicação nem as procedures que a referenciam.
 */
delete from adm.menus
 where modulo_id = 97
   and menu_pai_id is null
   and rota in ('empresas', 'usuarios');

update adm.menus
   set descricao = 'Mensagens'
 where modulo_id = 97
   and menu_pai_id is null
   and rota = 'mencoes'
   and descricao = 'Menções';
