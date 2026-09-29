/******************************************************************************************
 * Radar de Licitações — finalização da normalização de órgãos/unidades
 *
 * Continuação de V202609291000/V202609291100, no mesmo deploy: trava NOT NULL nas colunas
 * obrigatórias e derruba as colunas de texto antigas de pncp.contratacoes/audit.pncp_contratacoes,
 * que o backend deste mesmo deploy já deixa de ler/escrever, passando a usar só os FKs.
 */

-- Confere que o backfill (V202609291100) cobriu 100% das linhas antes de travar a
-- obrigatoriedade — aborta a migration se sobrar qualquer linha sem
-- orgao_entidade_id/unidade_orgao_id, em vez de deixar o SET NOT NULL falhar de forma menos óbvia.
do $$
declare
  v_faltantes integer;
begin
  select count(*) into v_faltantes
    from pncp.contratacoes
   where deleted_by is null
     and (orgao_entidade_id is null or unidade_orgao_id is null);

  if v_faltantes > 0 then
    raise exception 'V202609291100 não cobriu % linha(s) de pncp.contratacoes.', v_faltantes;
  end if;
end $$;

alter table pncp.contratacoes
	alter column orgao_entidade_id set not null,
	alter column unidade_orgao_id set not null;

-- ix_contratacoes_orgao_subrogado_cnpj e ix_contratacoes_unidade_orgao_uf_sigla (índices de
-- coluna única) somem sozinhos junto com as colunas abaixo.
alter table pncp.contratacoes
	drop column orgao_entidade_razao_social,
	drop column orgao_entidade_poder_id,
	drop column orgao_entidade_esfera_id,
	drop column unidade_orgao_codigo,
	drop column unidade_orgao_nome,
	drop column unidade_orgao_uf_sigla,
	drop column unidade_orgao_uf_nome,
	drop column unidade_orgao_municipio_nome,
	drop column unidade_orgao_codigo_ibge,
	drop column orgao_subrogado_cnpj,
	drop column orgao_subrogado_razao_social,
	drop column orgao_subrogado_poder_id,
	drop column orgao_subrogado_esfera_id,
	drop column unidade_subrogada_codigo,
	drop column unidade_subrogada_nome,
	drop column unidade_subrogada_uf_sigla,
	drop column unidade_subrogada_uf_nome,
	drop column unidade_subrogada_municipio_nome,
	drop column unidade_subrogada_codigo_ibge;

-- Espelho de auditoria acompanha (mirror 1:1 das colunas de negócio) — o histórico antigo já
-- gravado permanece intacto, só para de crescer com colunas obsoletas em linhas novas.
alter table audit.pncp_contratacoes
	drop column orgao_entidade_razao_social,
	drop column orgao_entidade_poder_id,
	drop column orgao_entidade_esfera_id,
	drop column unidade_orgao_codigo,
	drop column unidade_orgao_nome,
	drop column unidade_orgao_uf_sigla,
	drop column unidade_orgao_uf_nome,
	drop column unidade_orgao_municipio_nome,
	drop column unidade_orgao_codigo_ibge,
	drop column orgao_subrogado_cnpj,
	drop column orgao_subrogado_razao_social,
	drop column orgao_subrogado_poder_id,
	drop column orgao_subrogado_esfera_id,
	drop column unidade_subrogada_codigo,
	drop column unidade_subrogada_nome,
	drop column unidade_subrogada_uf_sigla,
	drop column unidade_subrogada_uf_nome,
	drop column unidade_subrogada_municipio_nome,
	drop column unidade_subrogada_codigo_ibge;

comment on table pncp.contratacoes is
  'Espelho de uma contratação (compra) importada do PNCP, isolado por Conta (conta_id) — '
  'cada conta mantém sua própria cópia das contratações que optou por acompanhar/importar. '
  'Órgão entidade/subrogado e unidade órgão/subrogada são referenciados via FK para '
  'pncp.orgaos/pncp.orgaos_unidades (orgao_entidade_id/unidade_orgao_id/orgao_subrogado_id/'
  'unidade_subrogada_id) — normalizados novamente a partir de V202609291000, revertendo a '
  'denormalização de V202609181000. '
  'PONTO DE EXTENSÃO PARA O MÓDULO DISPUTA: a futura tabela disputa.disputa deverá conter a '
  'coluna opcional "contratacao_pncp_id integer" com uma foreign key '
  '"contratacao_pncp_id references pncp.contratacoes(id) ON DELETE SET NULL" (ou similar), '
  'permitindo vincular a disputa à contratação PNCP de origem e preencher automaticamente '
  'os itens da disputa a partir de pncp.contratacoes_itens. Nenhuma FK nesse sentido é criada aqui, '
  'pois a tabela disputa.disputa ainda não existe neste repositório.';
