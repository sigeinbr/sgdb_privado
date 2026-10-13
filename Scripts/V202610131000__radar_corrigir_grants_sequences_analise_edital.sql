-- Corrigir grants de sequences que faltaram em V202610121200 (radar.analises_edital e
-- radar.analises_edital_solicitacoes usam "id serial"; sgisis precisa de USAGE para NEXTVAL
-- em inserts -> "permission denied for sequence analises_edital_id_seq").
-- Mesmo padrao de V202610031900.

grant usage, select on sequence radar.analises_edital_id_seq to sgisis;
grant usage, select on sequence radar.analises_edital_solicitacoes_id_seq to sgisis;

grant usage, select on sequence radar.analises_edital_id_seq to sgitec;
grant usage, select on sequence radar.analises_edital_solicitacoes_id_seq to sgitec;

grant select on sequence radar.analises_edital_id_seq to consulta;
grant select on sequence radar.analises_edital_solicitacoes_id_seq to consulta;
