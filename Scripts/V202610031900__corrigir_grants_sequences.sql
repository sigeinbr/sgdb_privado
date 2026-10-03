-- Corrigir grants de sequences que faltaram em V202610021400
-- sgisis precisa de USAGE + SELECT para fazer NEXTVAL em inserts

grant usage, select on sequence adm.cobrancas_id_seq to sgisis;
grant usage, select on sequence adm.trials_concedidos_id_seq to sgisis;

grant usage, select on sequence adm.cobrancas_id_seq to sgitec;
grant usage, select on sequence adm.trials_concedidos_id_seq to sgitec;
