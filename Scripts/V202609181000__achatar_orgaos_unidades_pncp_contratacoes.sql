/******************************************************************************************
 * REFATORAÇÃO: pncp.orgaos e pncp.orgaos_unidades deixam de ser tabelas normalizadas
 *
 * Continuação do achatamento iniciado em V202608201100 (que cobriu as 12 tabelas de domínio
 * puras id+nome, mas deixou orgaos/orgaos_unidades de fora por terem mais colunas). Esta
 * migration traz os dados de órgão/unidade para dentro de pncp.contratacoes e remove as
 * duas tabelas normalizadas.
 *
 * pncp.contratacoes referencia órgão/unidade por 4 colunas (não 1, como nas tabelas de
 * domínio puras): orgao_entidade_id/unidade_orgao_id (entidade principal, not null) e
 * orgao_subrogado_id/unidade_subrogada_id (entidade subrogada, opcional). Cada uma vira um
 * grupo de colunas denormalizadas com prefixo próprio. cnpj_orgao já existe na tabela e
 * cobre o CNPJ da entidade principal — não duplicado.
 */

/******************************************************************************************
 * 1) Novas colunas denormalizadas em pncp.contratacoes e audit.pncp_contratacoes
 */

alter table audit.pncp_contratacoes
	add column orgao_entidade_razao_social text,
	add column orgao_entidade_poder_id varchar(1),
	add column orgao_entidade_esfera_id varchar(1),
	add column unidade_orgao_codigo varchar(20),
	add column unidade_orgao_nome text,
	add column unidade_orgao_uf_sigla varchar(2),
	add column unidade_orgao_uf_nome text,
	add column unidade_orgao_municipio_nome text,
	add column unidade_orgao_codigo_ibge varchar(10),
	add column orgao_subrogado_cnpj varchar(14),
	add column orgao_subrogado_razao_social text,
	add column orgao_subrogado_poder_id varchar(1),
	add column orgao_subrogado_esfera_id varchar(1),
	add column unidade_subrogada_codigo varchar(20),
	add column unidade_subrogada_nome text,
	add column unidade_subrogada_uf_sigla varchar(2),
	add column unidade_subrogada_uf_nome text,
	add column unidade_subrogada_municipio_nome text,
	add column unidade_subrogada_codigo_ibge varchar(10);

alter table pncp.contratacoes
	add column orgao_entidade_razao_social text,
	add column orgao_entidade_poder_id varchar(1),
	add column orgao_entidade_esfera_id varchar(1),
	add column unidade_orgao_codigo varchar(20),
	add column unidade_orgao_nome text,
	add column unidade_orgao_uf_sigla varchar(2),
	add column unidade_orgao_uf_nome text,
	add column unidade_orgao_municipio_nome text,
	add column unidade_orgao_codigo_ibge varchar(10),
	add column orgao_subrogado_cnpj varchar(14),
	add column orgao_subrogado_razao_social text,
	add column orgao_subrogado_poder_id varchar(1),
	add column orgao_subrogado_esfera_id varchar(1),
	add column unidade_subrogada_codigo varchar(20),
	add column unidade_subrogada_nome text,
	add column unidade_subrogada_uf_sigla varchar(2),
	add column unidade_subrogada_uf_nome text,
	add column unidade_subrogada_municipio_nome text,
	add column unidade_subrogada_codigo_ibge varchar(10),
	add constraint contratacoes_orgao_subrogado_cnpj_chk
		check (orgao_subrogado_cnpj is null or orgao_subrogado_cnpj ~ '^[0-9]{14}$');

/******************************************************************************************
 * 2) Popular as novas colunas a partir das tabelas normalizadas, antes de removê-las
 */

update pncp.contratacoes c set
	orgao_entidade_razao_social = o.razao_social,
	orgao_entidade_poder_id = o.poder_id,
	orgao_entidade_esfera_id = o.esfera_id
from pncp.orgaos o where o.id = c.orgao_entidade_id;

update pncp.contratacoes c set
	unidade_orgao_codigo = u.codigo_unidade,
	unidade_orgao_nome = u.nome_unidade,
	unidade_orgao_uf_sigla = u.uf_sigla,
	unidade_orgao_uf_nome = u.uf_nome,
	unidade_orgao_municipio_nome = u.municipio_nome,
	unidade_orgao_codigo_ibge = u.codigo_ibge
from pncp.orgaos_unidades u where u.id = c.unidade_orgao_id;

update pncp.contratacoes c set
	orgao_subrogado_cnpj = o.cnpj,
	orgao_subrogado_razao_social = o.razao_social,
	orgao_subrogado_poder_id = o.poder_id,
	orgao_subrogado_esfera_id = o.esfera_id
from pncp.orgaos o where o.id = c.orgao_subrogado_id;

update pncp.contratacoes c set
	unidade_subrogada_codigo = u.codigo_unidade,
	unidade_subrogada_nome = u.nome_unidade,
	unidade_subrogada_uf_sigla = u.uf_sigla,
	unidade_subrogada_uf_nome = u.uf_nome,
	unidade_subrogada_municipio_nome = u.municipio_nome,
	unidade_subrogada_codigo_ibge = u.codigo_ibge
from pncp.orgaos_unidades u where u.id = c.unidade_subrogada_id;

alter table pncp.contratacoes
	alter column orgao_entidade_razao_social set not null,
	alter column unidade_orgao_codigo set not null;

/******************************************************************************************
 * 3) Remover as FKs/colunas antigas de pncp.contratacoes e audit.pncp_contratacoes
 *
 * DROP COLUMN remove automaticamente os índices de coluna única associados
 * (ix_contratacoes_orgao_entidade, ix_contratacoes_unidade_orgao, ix_contratacoes_orgao_subrogado).
 */

alter table pncp.contratacoes drop constraint contratacoes_orgao_entidade_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_unidade_orgao_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_orgao_subrogado_id_fkey;
alter table pncp.contratacoes drop constraint contratacoes_unidade_subrogada_id_fkey;

alter table pncp.contratacoes
	drop column orgao_entidade_id,
	drop column unidade_orgao_id,
	drop column orgao_subrogado_id,
	drop column unidade_subrogada_id;

alter table audit.pncp_contratacoes
	drop column orgao_entidade_id,
	drop column unidade_orgao_id,
	drop column orgao_subrogado_id,
	drop column unidade_subrogada_id;

comment on table pncp.contratacoes is
  'Espelho de uma contratação (compra) importada do PNCP — dado público único e global, '
  'compartilhado por todas as Contas (ver pncp.contas_contratacoes para o vínculo de '
  'acompanhamento por Conta). Órgão entidade/subrogado e unidade órgão/subrogada são '
  'denormalizados diretamente nas colunas orgao_entidade_*/unidade_orgao_*/orgao_subrogado_*/'
  'unidade_subrogada_* — pncp.orgaos e pncp.orgaos_unidades não existem mais como tabelas '
  'normalizadas. '
  'PONTO DE EXTENSÃO PARA O MÓDULO DISPUTA: a futura tabela disputa.disputa deverá conter a '
  'coluna opcional "contratacao_pncp_id integer" com uma foreign key '
  '"contratacao_pncp_id references pncp.contratacoes(id) ON DELETE SET NULL" (ou similar), '
  'permitindo vincular a disputa à contratação PNCP de origem e preencher automaticamente '
  'os itens da disputa a partir de pncp.contratacoes_itens. Nenhuma FK nesse sentido é criada aqui, '
  'pois a tabela disputa.disputa ainda não existe neste repositório.';

create index ix_contratacoes_orgao_subrogado_cnpj on pncp.contratacoes (orgao_subrogado_cnpj)
	where orgao_subrogado_cnpj is not null;
create index ix_contratacoes_unidade_orgao_uf_sigla on pncp.contratacoes (unidade_orgao_uf_sigla);

/******************************************************************************************
 * 4) Derrubar as tabelas antigas (orgaos_unidades antes de orgaos, por causa da FK entre elas)
 *
 * Os 5 triggers de auditoria de cada tabela somem junto com o DROP TABLE.
 */

drop table pncp.orgaos_unidades;
drop table audit.pncp_orgaos_unidades;

drop table pncp.orgaos;
drop table audit.pncp_orgaos;
