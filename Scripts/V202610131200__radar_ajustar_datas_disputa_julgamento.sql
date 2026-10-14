-- 1) data_julgamento_inicio vem só da mensagem de julgamento.
--    a) corrige quem ficou com data aproximada posterior à mensagem (hoje: id 42)
UPDATE pncp.contratacoes c
   SET data_julgamento_inicio = m.primeira
  FROM (SELECT contratacao_id, MIN(data_hora) AS primeira
          FROM pncp.contratacoes_mensagens
         WHERE texto ILIKE '%etapa de julgamento de propostas foi iniciada%'
         GROUP BY contratacao_id) m
 WHERE m.contratacao_id = c.id
   AND c.data_julgamento_inicio IS DISTINCT FROM m.primeira;

--    b) limpa a data aproximada de quem não tem a mensagem (hoje: id 45).
--       situacao_calculada não muda: a regra "não regride de em_julgamento" segura a fase.
UPDATE pncp.contratacoes c
   SET data_julgamento_inicio = NULL
 WHERE c.data_julgamento_inicio IS NOT NULL
   AND NOT EXISTS (SELECT 1
                     FROM pncp.contratacoes_mensagens m
                    WHERE m.contratacao_id = c.id
                      AND m.texto ILIKE '%etapa de julgamento de propostas foi iniciada%');

-- 2) data_disputa_inicio usa o encerramento das propostas quando não há informação
--    da plataforma (hoje: 35 linhas). A fase não muda: início = encerramento
--    continua em_disputa depois do encerramento.
UPDATE pncp.contratacoes
   SET data_disputa_inicio = data_encerramento_proposta
 WHERE data_disputa_inicio IS NULL
   AND data_encerramento_proposta IS NOT NULL;
