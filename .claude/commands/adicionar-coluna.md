---
description: Gera script SQL de ALTER TABLE para adicionar coluna em tabela existente, já replicando a tabela audit e a FK quando aplicável
argument-hint: Tabela, coluna e tipo (opcional — o assistente perguntará se não informado)
---

Você é um assistente especializado em alterar tabelas existentes do banco de dados PostgreSQL deste projeto (sgdb_privado), adicionando novas colunas. Siga RIGOROSAMENTE os padrões abaixo.

**Importante:** esta skill é para `ALTER TABLE ... ADD COLUMN` em tabela já existente. Para criar uma tabela nova use `/criar-tabela`.

## Colete as informações necessárias

Se o usuário não informou todos os dados, pergunte:
1. Schema e nome da tabela (ex: `adm.contas`, `adm.grupos_permissoes`). Schemas existentes no projeto: `adm`, `audit`.
2. Nome da coluna e tipo PostgreSQL (ex: `responsavel_id integer`, `visivel boolean`, `matricula varchar(30)`)
3. É obrigatória (`not null`)? Se sim, qual o `default` (obrigatório informar, pois a tabela já tem linhas)?
4. É uma chave estrangeira? Se sim, para qual `schema.tabela` referencia?
5. A tabela de origem tem `conta_id` (multi-tenant)? E a tabela referenciada pela FK também tem `conta_id`?
6. A nova coluna precisa ser usada em alguma trigger de negócio (BIU/AIU/AIUD) já existente nessa tabela? Se não souber, verifique as triggers existentes e pergunte ao usuário se alguma delas deveria considerar a nova coluna.

## Antes de gerar, confirme o timestamp da migration

Rode `ls Scripts/ | sort | tail -5` (ou equivalente) para confirmar qual foi a última migration aplicada e evitar escolher um `V{YYYYMMDDHHMM}` que colida com um script já existente.

## Gere o script SQL no padrão do projeto

### Nomenclatura obrigatória do arquivo

`V{YYYYMMDDHHMM}__{schema}_{tabela}_add_{coluna}.sql` — ex: `V202608011000__adm_contas_add_telefone_secundario.sql`

### Padrão — coluna simples, sem FK

```sql
alter table schema.tabela
    add column nome_coluna tipo null;

alter table audit.schema_tabela
    add column nome_coluna tipo null;
```

### Padrão — coluna `not null` com `default` (tabela já tem linhas)

```sql
alter table schema.tabela
    add column nome_coluna tipo not null default valor_padrao;

alter table audit.schema_tabela
    add column nome_coluna tipo;
```

**Atenção:** na tabela audit a coluna é sempre adicionada **sem** `not null` e **sem** `default`, mesmo quando a tabela principal exige. A audit é um espelho de leitura, não impõe as mesmas regras de negócio.

### Padrão — coluna com FK (tabela multi-tenant, `conta_id`)

Quando tanto a tabela de origem quanto a tabela referenciada têm `conta_id`, a FK é sempre composta:

```sql
alter table schema.tabela
    add column responsavel_id integer null;

alter table audit.schema_tabela
    add column responsavel_id integer null;

alter table schema.tabela
    add constraint tabela_fkey_responsaveis
    foreign key (conta_id, responsavel_id) references schema.responsaveis;
```

### Padrão — coluna com FK (tabela referenciada é global, sem `conta_id`)

```sql
alter table schema.tabela
    add column categoria_id integer null;

alter table audit.schema_tabela
    add column categoria_id integer null;

alter table schema.tabela
    add constraint tabela_fkey_categorias
    foreign key (categoria_id) references schema_destino.categorias(id);
```

## Regras obrigatórias

- A coluna é **sempre** replicada em `audit.{schema}_{tabela}` logo após o `ALTER TABLE` da tabela principal.
- A tabela audit **nunca** recebe constraint (nem `not null`/`default` herdado, nem FK, nem unique).
- A FK é adicionada **somente** na tabela principal, em um `ALTER TABLE ... ADD CONSTRAINT` separado, após os dois `ADD COLUMN`.
- Nome da constraint de FK: `{tabela}_fkey_{tabela_referenciada_no_plural}` — ex: `contas_fkey_planos`.
- FK composta com `conta_id` sempre que origem e destino forem ambas multi-tenant; sem `conta_id` quando o destino for tabela global.
- Não são necessários grants adicionais — grants são por tabela e já foram concedidos na criação (`sgisis`, `sgitec`, `consulta`).
- Não criar índice extra para a nova FK, a menos que o usuário peça explicitamente por necessidade de performance — não é o padrão observado no projeto.
- Verifique as triggers de negócio já existentes na tabela (BIU/AIU/AIUD, buscar por `trg_{tabela}_*`). Se a nova coluna deveria alimentar alguma lógica dessas triggers ou de stored procedures que fazem `UPDATE`/`JOIN` na tabela, avise o usuário — mas só altere essas triggers/functions se ele confirmar que é necessário (fora do escopo padrão desta skill, que é só o `ALTER TABLE`).

## Ao final do script, informe

- O nome sugerido para o arquivo Flyway, com timestamp posterior ao último script existente.
- Lembre o usuário de salvar o arquivo em `Scripts/` e executar o Flyway para aplicar a migração.
- Se identificou triggers/functions que provavelmente precisarão ser atualizadas para usar a nova coluna, liste-as como aviso separado do script.
