alter table pncp.contas_contratacoes
    drop column mensagens_alertadas_ate;

alter table audit.pncp_contas_contratacoes
    drop column mensagens_alertadas_ate;

alter table pncp.contas_contratacoes
    add column monitorada_em timestamp null;

alter table pncp.contas_contratacoes
    add column mensagens_verificadas_ate timestamp null;

alter table audit.pncp_contas_contratacoes
    add column monitorada_em timestamp;

alter table audit.pncp_contas_contratacoes
    add column mensagens_verificadas_ate timestamp;
