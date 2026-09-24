alter table pncp.contratacoes_itens
    add column cnpj_vencedor varchar(30) null;

alter table audit.pncp_contratacoes_itens
    add column cnpj_vencedor varchar(30) null;

create index ix_contratacoes_itens_cnpj_vencedor
    on pncp.contratacoes_itens (cnpj_vencedor) where cnpj_vencedor is not null;
