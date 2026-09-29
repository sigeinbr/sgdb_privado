/******************************************************************************************
 * Radar de Licitações — backfill de pncp.orgaos / pncp.orgaos_unidades
 *
 * Continuação de V202609291000. Popula o catálogo global de órgãos/unidades a partir das
 * colunas de texto ainda presentes em pncp.contratacoes e preenche os FKs novos
 * (orgao_entidade_id/unidade_orgao_id/orgao_subrogado_id/unidade_subrogada_id). Os INSERTs
 * usam ON CONFLICT DO NOTHING e o UPDATE final é ignorado pela trigger de auditoria quando não
 * muda nada (audit.func_audit_before) — mantém a migration idempotente/reexecutável em caso de
 * necessidade, mesmo rodando uma única vez por deploy.
 *
 * V202609291200 (próxima migration) trava NOT NULL e derruba as colunas de texto antigas —
 * depende deste backfill ter coberto 100% das linhas.
 */

-- Backfill de pncp.orgaos: um órgão pode aparecer como órgão principal em uma contratação e
-- como sub-rogado em outra — por isso o UNION antes do dedup por cnpj, escolhendo a linha de
-- contratação mais recente (ultima_sincronizacao_em) como fonte dos dados de texto.
insert into pncp.orgaos
  (cnpj, razao_social, poder_id, esfera_id, dados_json, ultima_sincronizacao_em, created_by, updated_by)
select distinct on (cnpj)
  cnpj, razao_social, poder_id, esfera_id, dados_json, ultima_sincronizacao_em,
  'backfill-normalizacao', 'backfill-normalizacao'
  from (
    select cnpj_orgao as cnpj, orgao_entidade_razao_social as razao_social,
           orgao_entidade_poder_id as poder_id, orgao_entidade_esfera_id as esfera_id,
           coalesce(dados_json -> 'orgaoEntidade', '{}'::jsonb) as dados_json,
           ultima_sincronizacao_em
      from pncp.contratacoes
     where deleted_by is null
     union all
    select orgao_subrogado_cnpj, orgao_subrogado_razao_social,
           orgao_subrogado_poder_id, orgao_subrogado_esfera_id,
           coalesce(dados_json -> 'orgaoSubRogado', '{}'::jsonb),
           ultima_sincronizacao_em
      from pncp.contratacoes
     where deleted_by is null and orgao_subrogado_cnpj is not null
  ) fontes
 order by cnpj, ultima_sincronizacao_em desc
on conflict (cnpj) do nothing;

-- Backfill de pncp.orgaos_unidades: mesma lógica, dedup por (orgao_id, codigo_unidade).
insert into pncp.orgaos_unidades
  (orgao_id, codigo_unidade, nome_unidade, uf_sigla, uf_nome, municipio_nome, codigo_ibge, dados_json, created_by, updated_by)
select distinct on (o.id, fontes.codigo_unidade)
  o.id, fontes.codigo_unidade, fontes.nome_unidade, fontes.uf_sigla, fontes.uf_nome,
  fontes.municipio_nome, fontes.codigo_ibge, fontes.dados_json,
  'backfill-normalizacao', 'backfill-normalizacao'
  from (
    select cnpj_orgao as cnpj, unidade_orgao_codigo as codigo_unidade, unidade_orgao_nome as nome_unidade,
           unidade_orgao_uf_sigla as uf_sigla, unidade_orgao_uf_nome as uf_nome,
           unidade_orgao_municipio_nome as municipio_nome, unidade_orgao_codigo_ibge as codigo_ibge,
           coalesce(dados_json -> 'unidadeOrgao', '{}'::jsonb) as dados_json,
           ultima_sincronizacao_em
      from pncp.contratacoes
     where deleted_by is null
     union all
    select orgao_subrogado_cnpj, unidade_subrogada_codigo, unidade_subrogada_nome,
           unidade_subrogada_uf_sigla, unidade_subrogada_uf_nome,
           unidade_subrogada_municipio_nome, unidade_subrogada_codigo_ibge,
           coalesce(dados_json -> 'unidadeSubRogada', '{}'::jsonb),
           ultima_sincronizacao_em
      from pncp.contratacoes
     where deleted_by is null and orgao_subrogado_cnpj is not null and unidade_subrogada_codigo is not null
  ) fontes
  join pncp.orgaos o on o.cnpj = fontes.cnpj
 order by o.id, fontes.codigo_unidade, fontes.ultima_sincronizacao_em desc
on conflict (orgao_id, codigo_unidade) do nothing;

-- Preenche os FKs novos em contratacoes a partir do catálogo recém-populado.
update pncp.contratacoes c
   set orgao_entidade_id = fk.orgao_entidade_id,
       unidade_orgao_id = fk.unidade_orgao_id,
       orgao_subrogado_id = fk.orgao_subrogado_id,
       unidade_subrogada_id = fk.unidade_subrogada_id
  from (
    select c2.id,
           oe.id as orgao_entidade_id,
           ue.id as unidade_orgao_id,
           os.id as orgao_subrogado_id,
           us.id as unidade_subrogada_id
      from pncp.contratacoes c2
      join pncp.orgaos oe on oe.cnpj = c2.cnpj_orgao
      join pncp.orgaos_unidades ue on ue.orgao_id = oe.id and ue.codigo_unidade = c2.unidade_orgao_codigo
      left join pncp.orgaos os on os.cnpj = c2.orgao_subrogado_cnpj
      left join pncp.orgaos_unidades us on us.orgao_id = os.id and us.codigo_unidade = c2.unidade_subrogada_codigo
     where c2.deleted_by is null
  ) fk
 where fk.id = c.id;
