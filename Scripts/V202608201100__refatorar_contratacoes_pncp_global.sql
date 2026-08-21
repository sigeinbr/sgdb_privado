/******************************************************************************************
 * REFATORAÇÃO: pncp.contratacoes deixa de ser isolada por Conta
 *
 * A contratação em si é um dado público único (vem da API do PNCP) — o que varia por Conta
 * é apenas o "acompanhamento" (quais Contas optaram por importar/seguir aquela contratação).
 * Esta migration:
 *   1) cria pncp.contas_contratacoes para representar esse acompanhamento;
 *   2) deduplica linhas de pncp.contratacoes que hoje são cópias da mesma contratação
 *      pública importadas por Contas diferentes;
 *   3) remove conta_id de pncp.contratacoes e das suas 6 tabelas filhas, tornando-as globais;
 *   4) achata em colunas de texto as 12 tabelas de domínio puras (id+nome, sem seed, sem
 *      estrutura adicional) que normalizavam campos como modalidade, situação, benefício etc.
 *
 * pncp.orgaos e pncp.orgaos_unidades ficam FORA do achatamento — têm CNPJ, razão social,
 * UF, município e dados_json, e continuam normalizadas.
 */

/******************************************************************************************
 * 1) TABELA: pncp.contas_contratacoes
 *
 * Vínculo de acompanhamento entre Conta e contratação pública PNCP. A contratação é um
 * dado público único e global; esta tabela só registra que uma Conta optou por
 * acompanhar/importar aquela contratação — sem duplicar o dado da contratação. Segue o
 * mesmo padrão de chave composta natural de adm.contas_modulos (sem id serial próprio).
 */
create table pncp.contas_contratacoes(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null,
	contratacao_id integer not null,

	constraint contas_contratacoes_pkey primary key (conta_id, contratacao_id),
	constraint contas_contratacoes_conta_id_fkey foreign key (conta_id) references adm.contas (id),
	constraint contas_contratacoes_contratacao_id_fkey foreign key (contratacao_id) references pncp.contratacoes (id) on delete cascade
);
comment on table pncp.contas_contratacoes is
  'Vínculo de acompanhamento entre Conta e contratação pública PNCP (pncp.contratacoes). '
  'A contratação é um dado público único e global; esta tabela apenas registra que uma '
  'Conta optou por acompanhar/importar aquela contratação — sem duplicar o dado da contratação.';

grant select, insert, update, delete on pncp.contas_contratacoes to sgisis;
grant select, insert, update, delete on pncp.contas_contratacoes to sgitec;
grant select on pncp.contas_contratacoes to consulta;

create index ix_contas_contratacoes_contratacao_id on pncp.contas_contratacoes (contratacao_id);

/******************************************************************************************
 * TABELA: audit.pncp_contas_contratacoes
 */
create table audit.pncp_contas_contratacoes (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	contratacao_id integer not null
);

create index pncp_contas_contratacoes_idx1 on audit.pncp_contas_contratacoes(dh_audit,oper_audit,usuario_audit);
create index pncp_contas_contratacoes_idx2 on audit.pncp_contas_contratacoes(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_contas_contratacoes to sgisis;
grant select on audit.pncp_contas_contratacoes to sgitec;
grant select on audit.pncp_contas_contratacoes to consulta;

create trigger audit_bi before insert on pncp.contas_contratacoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.contas_contratacoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.contas_contratacoes for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.contas_contratacoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.contas_contratacoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * 2) Deduplicação de pncp.contratacoes por numero_controle_pncp
 *
 * Antes da refatoração, a mesma contratação pública pode existir em N linhas (uma por Conta
 * que a importou), todas com o mesmo numero_controle_pncp mas conta_id/id diferentes.
 * Escolhe-se como canônica a linha de menor id (primeira sincronizada); popula-se
 * pncp.contas_contratacoes com todos os pares (conta_id, id_canonico) observados e então
 * apagam-se as linhas não-canônicas. As 6 tabelas filhas de pncp.contratacoes já têm FK
 * "on delete cascade", então seus registros duplicados somem automaticamente.
 *
 * Idempotente: roda sem efeito em base vazia ou já deduplicada.
 */
do $$
declare
  v_conflitos integer;
begin
  select count(*) into v_conflitos
  from (
    select cnpj_orgao, ano_compra, sequencial_compra, count(distinct numero_controle_pncp) as qtd
    from pncp.contratacoes
    group by cnpj_orgao, ano_compra, sequencial_compra
    having count(distinct numero_controle_pncp) > 1
  ) x;

  if v_conflitos > 0 then
    raise exception
      'Encontradas % combinações de (cnpj_orgao,ano_compra,sequencial_compra) associadas a '
      'mais de um numero_controle_pncp — investigar manualmente antes de aplicar esta migration.',
      v_conflitos;
  end if;
end $$;

insert into pncp.contas_contratacoes (conta_id, contratacao_id)
select distinct c.conta_id, m.id_canonico
from pncp.contratacoes c
join (
  select numero_controle_pncp, min(id) as id_canonico
  from pncp.contratacoes
  group by numero_controle_pncp
) m on m.numero_controle_pncp = c.numero_controle_pncp
on conflict (conta_id, contratacao_id) do nothing;

delete from pncp.contratacoes c
using (
  select numero_controle_pncp, min(id) as id_canonico
  from pncp.contratacoes
  group by numero_controle_pncp
) m
where c.numero_controle_pncp = m.numero_controle_pncp
  and c.id <> m.id_canonico;

/******************************************************************************************
 * 3) pncp.contratacoes deixa de ter conta_id
 *
 * DROP COLUMN remove automaticamente a FK implícita para adm.contas, o índice
 * ix_contratacoes_conta_id e as duas unique constraints que incluíam conta_id.
 */
alter table pncp.contratacoes drop column conta_id;

alter table pncp.contratacoes
  add constraint contratacoes_ukey_numero_controle unique (numero_controle_pncp),
  add constraint contratacoes_ukey_cnpj_ano_sequencial unique (cnpj_orgao, ano_compra, sequencial_compra);

comment on table pncp.contratacoes is
  'Espelho de uma contratação (compra) importada do PNCP — dado público único e global, '
  'compartilhado por todas as Contas (ver pncp.contas_contratacoes para o vínculo de '
  'acompanhamento por Conta). '
  'PONTO DE EXTENSÃO PARA O MÓDULO DISPUTA: a futura tabela disputa.disputa deverá conter a '
  'coluna opcional "contratacao_pncp_id integer" com uma foreign key '
  '"contratacao_pncp_id references pncp.contratacoes(id) ON DELETE SET NULL" (ou similar), '
  'permitindo vincular a disputa à contratação PNCP de origem e preencher automaticamente '
  'os itens da disputa a partir de pncp.contratacoes_itens. Nenhuma FK nesse sentido é criada aqui, '
  'pois a tabela disputa.disputa ainda não existe neste repositório.';

/******************************************************************************************
 * 4) As 6 tabelas filhas de pncp.contratacoes também deixam de ter conta_id
 *
 * Cada uma é faceta do mesmo dado público da contratação, não do vínculo de Conta. Todas
 * têm PK própria em id serial (não composta com conta_id), então o drop não afeta a PK.
 */
alter table pncp.contratacoes_itens               drop column conta_id;
alter table pncp.contratacoes_fontes_orcamentarias drop column conta_id;
alter table pncp.contratacoes_arquivos             drop column conta_id;
alter table pncp.contratacoes_situacoes            drop column conta_id;
alter table pncp.contratacoes_itens_resultados     drop column conta_id;
alter table pncp.contratacoes_mensagens            drop column conta_id;

alter table pncp.contratacoes_mensagens
  add constraint contratacoes_mensagens_ukey unique (chave_mensagem_origem);

/******************************************************************************************
 * 5) Espelhar a remoção de conta_id nas 7 tabelas audit.* correspondentes
 */
alter table audit.pncp_contratacoes                       drop column conta_id;
alter table audit.pncp_contratacoes_itens                 drop column conta_id;
alter table audit.pncp_contratacoes_fontes_orcamentarias  drop column conta_id;
alter table audit.pncp_contratacoes_arquivos              drop column conta_id;
alter table audit.pncp_contratacoes_situacoes             drop column conta_id;
alter table audit.pncp_contratacoes_itens_resultados      drop column conta_id;
alter table audit.pncp_contratacoes_mensagens             drop column conta_id;

/******************************************************************************************
 * 6) Achatamento das tabelas de domínio puras (id+nome, sem seed, sem estrutura adicional)
 *
 * Mantém a coluna "_id" (código numérico já enviado pela API do PNCP), só remove a FK/
 * normalização, e adiciona "_nome"/"_descricao" ao lado — mesmo espírito de
 * pncp.orgaos.poder_id/esfera_id (código sem FK, com significado documentado em comentário).
 */

-- 6.A pncp.contratacoes: modalidade, modo_disputa, tipo_instrumento_convocatorio,
--     amparo_legal, situacao_compra, orcamento_sigiloso

alter table audit.pncp_contratacoes
  add column modalidade_nome text,
  add column modo_disputa_nome text,
  add column tipo_instrumento_convocatorio_nome text,
  add column amparo_legal_nome text,
  add column amparo_legal_descricao text,
  add column situacao_compra_nome text,
  add column orcamento_sigiloso_nome text;

alter table pncp.contratacoes
  add column modalidade_nome text,
  add column modo_disputa_nome text,
  add column tipo_instrumento_convocatorio_nome text,
  add column amparo_legal_nome text,
  add column amparo_legal_descricao text,
  add column situacao_compra_nome text,
  add column orcamento_sigiloso_nome text;

update pncp.contratacoes c set modalidade_nome = d.nome
  from pncp.modalidades_contratacao d where d.id = c.modalidade_id;

update pncp.contratacoes c set modo_disputa_nome = d.nome
  from pncp.modos_disputa d where d.id = c.modo_disputa_id;

update pncp.contratacoes c set tipo_instrumento_convocatorio_nome = d.nome
  from pncp.tipos_instrumentos_convocatorios d where d.id = c.tipo_instrumento_convocatorio_id;

update pncp.contratacoes c set amparo_legal_nome = d.nome, amparo_legal_descricao = d.descricao
  from pncp.amparos_legais d where d.id = c.amparo_legal_id;

update pncp.contratacoes c set situacao_compra_nome = d.nome
  from pncp.situacoes_compra d where d.id = c.situacao_compra_id;

update pncp.contratacoes c set orcamento_sigiloso_nome = d.nome
  from pncp.tipos_orcamento_sigiloso d where d.id = c.orcamento_sigiloso_id;

alter table pncp.contratacoes drop constraint contratacoes_modalidade_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_modo_disputa_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_tipo_instrumento_convocatorio_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_amparo_legal_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_situacao_compra_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_orcamento_sigiloso_id_fkey;

-- 6.B pncp.contratacoes_itens: item_categoria, criterio_julgamento, situacao_item, tipo_beneficio

alter table audit.pncp_contratacoes_itens
  add column item_categoria_nome text,
  add column criterio_julgamento_nome text,
  add column situacao_item_nome text,
  add column tipo_beneficio_nome text;

alter table pncp.contratacoes_itens
  add column item_categoria_nome text,
  add column criterio_julgamento_nome text,
  add column situacao_item_nome text,
  add column tipo_beneficio_nome text;

update pncp.contratacoes_itens c set item_categoria_nome = d.nome
  from pncp.categorias_itens d where d.id = c.item_categoria_id;

update pncp.contratacoes_itens c set criterio_julgamento_nome = d.nome
  from pncp.criterios_julgamento d where d.id = c.criterio_julgamento_id;

update pncp.contratacoes_itens c set situacao_item_nome = d.nome
  from pncp.situacoes_item d where d.id = c.situacao_item_id;

update pncp.contratacoes_itens c set tipo_beneficio_nome = d.nome
  from pncp.tipos_beneficios d where d.id = c.tipo_beneficio_id;

alter table pncp.contratacoes_itens drop constraint contratacoes_itens_item_categoria_id_fkey;
alter table pncp.contratacoes_itens drop constraint contratacoes_itens_criterio_julgamento_id_fkey;
alter table pncp.contratacoes_itens drop constraint contratacoes_itens_situacao_item_id_fkey;
alter table pncp.contratacoes_itens drop constraint contratacoes_itens_tipo_beneficio_id_fkey;

-- 6.C pncp.contratacoes_arquivos: tipo_documento (tem nome + descrição)

alter table audit.pncp_contratacoes_arquivos
  add column tipo_documento_nome text,
  add column tipo_documento_descricao text;

alter table pncp.contratacoes_arquivos
  add column tipo_documento_nome text,
  add column tipo_documento_descricao text;

update pncp.contratacoes_arquivos c
  set tipo_documento_nome = d.nome, tipo_documento_descricao = d.descricao
  from pncp.tipos_documentos d where d.id = c.tipo_documento_id;

alter table pncp.contratacoes_arquivos drop constraint contratacoes_arquivos_tipo_documento_id_fkey;

-- 6.D pncp.contratacoes_situacoes: situacao_compra (coluna de negócio era not null)

alter table audit.pncp_contratacoes_situacoes
  add column situacao_compra_nome text;

alter table pncp.contratacoes_situacoes
  add column situacao_compra_nome text;

update pncp.contratacoes_situacoes c set situacao_compra_nome = d.nome
  from pncp.situacoes_compra d where d.id = c.situacao_compra_id;

alter table pncp.contratacoes_situacoes alter column situacao_compra_nome set not null;

alter table pncp.contratacoes_situacoes drop constraint contratacoes_situacoes_situacao_compra_id_fkey;

-- 6.E pncp.contratacoes_itens_resultados: situacao_resultado_item
-- Nome de FK autogerado ultrapassa 63 caracteres (NAMEDATALEN) e vem truncado no catálogo
-- de forma imprevisível de adivinhar — localizar dinamicamente via pg_constraint.

alter table audit.pncp_contratacoes_itens_resultados
  add column situacao_compra_item_resultado_nome text;

alter table pncp.contratacoes_itens_resultados
  add column situacao_compra_item_resultado_nome text;

update pncp.contratacoes_itens_resultados c set situacao_compra_item_resultado_nome = d.nome
  from pncp.situacoes_resultado_item d where d.id = c.situacao_compra_item_resultado_id;

do $$
declare
  v_fk_name text;
begin
  select conname into v_fk_name
  from pg_constraint
  where conrelid = 'pncp.contratacoes_itens_resultados'::regclass
    and contype = 'f'
    and confrelid = 'pncp.situacoes_resultado_item'::regclass;

  if v_fk_name is null then
    raise exception 'FK de pncp.contratacoes_itens_resultados para pncp.situacoes_resultado_item não encontrada.';
  end if;

  execute format('alter table pncp.contratacoes_itens_resultados drop constraint %I', v_fk_name);
end $$;

-- 6.F Drop das 12 tabelas de domínio + espelhos audit (só após remover todas as FKs que
--     apontam para cada uma — situacoes_compra é referenciada por duas tabelas, já tratadas
--     nos blocos 6.A e 6.D acima)

drop table pncp.modalidades_contratacao;
drop table audit.pncp_modalidades_contratacao;

drop table pncp.modos_disputa;
drop table audit.pncp_modos_disputa;

drop table pncp.tipos_instrumentos_convocatorios;
drop table audit.pncp_tipos_instrumentos_convocatorios;

drop table pncp.amparos_legais;
drop table audit.pncp_amparos_legais;

drop table pncp.situacoes_compra;
drop table audit.pncp_situacoes_compra;

drop table pncp.tipos_orcamento_sigiloso;
drop table audit.pncp_tipos_orcamento_sigiloso;

drop table pncp.categorias_itens;
drop table audit.pncp_categorias_itens;

drop table pncp.criterios_julgamento;
drop table audit.pncp_criterios_julgamento;

drop table pncp.tipos_beneficios;
drop table audit.pncp_tipos_beneficios;

drop table pncp.situacoes_item;
drop table audit.pncp_situacoes_item;

drop table pncp.situacoes_resultado_item;
drop table audit.pncp_situacoes_resultado_item;

drop table pncp.tipos_documentos;
drop table audit.pncp_tipos_documentos;
