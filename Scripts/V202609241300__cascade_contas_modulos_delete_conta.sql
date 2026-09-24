-- Ao excluir uma conta, remove em cascata seus vínculos em adm.contas_modulos.
alter table adm.contas_modulos
  drop constraint contas_modulos_conta_id_fkey,
  add constraint contas_modulos_conta_id_fkey
    foreign key (conta_id) references adm.contas (id) on delete cascade;
