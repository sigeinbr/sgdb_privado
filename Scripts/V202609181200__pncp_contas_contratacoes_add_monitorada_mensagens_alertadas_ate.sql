alter table pncp.contas_contratacoes
    add column monitorada boolean not null default false;

alter table pncp.contas_contratacoes
    add column mensagens_alertadas_ate timestamp null;

alter table audit.pncp_contas_contratacoes
    add column monitorada boolean;

alter table audit.pncp_contas_contratacoes
    add column mensagens_alertadas_ate timestamp;
