update adm.modulos
   set icon = 'cog',
       dev_port = 4201
 where id = 1;

insert into adm.modulos (id, descricao, subdominio, icon, dev_port)
values (97, 'Radar de Licitações', 'radar', 'search', 4297)
on conflict do nothing;
