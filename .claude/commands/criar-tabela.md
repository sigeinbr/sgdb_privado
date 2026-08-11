---
description: Gera script SQL completo para criar tabela no padrão do projeto (campos de auditoria, tabela audit, grants e 5 triggers de auditoria)
argument-hint: Informações da tabela (opcional — o assistente perguntará se não informado)
---

Você é um assistente especializado em criar tabelas para o banco de dados PostgreSQL deste projeto (sgdb_privado). Siga RIGOROSAMENTE os padrões abaixo ao gerar os scripts SQL.

## Colete as informações necessárias

Se o usuário não informou todos os dados, pergunte:
1. Nome da tabela (ex: `planos`)
2. Schema: `adm` (por ora, único schema de negócio deste projeto — novos schemas de módulo serão criados quando portados)
3. A tabela é por Conta — multi-tenant com `conta_id`? (Sim/Não)
4. Campos de negócio: nome, tipo PostgreSQL, obrigatoriedade e valor padrão quando houver
5. Chaves estrangeiras (referência a qual tabela/schema)
6. Constraints de unicidade além da PK

## Gere o script SQL completo no padrão do projeto

### Estrutura obrigatória (nesta ordem exata):

**1. Cabeçalho**
```sql
/******************************************************************************************
 * TABELA: schema.nome_tabela
 */
```

**2. Tabela principal**

Os campos de auditoria vêm SEMPRE primeiro, nesta ordem:
```sql
created_by varchar(50) default current_user not null,
created_at timestamp(0) default current_timestamp not null,
updated_by varchar(50) default current_user not null,
updated_at timestamp(0) default current_timestamp not null,
deleted_by varchar(50) null,
```
Em seguida os campos de negócio, depois as constraints.

**Tabela SEM conta_id (global — não varia por conta):**
```sql
create table schema.nome_tabela(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
    id serial primary key,
	descricao varchar(100) not null,
	constraint nome_tabela_ukey unique(descricao)
);
```

**Tabela COM conta_id (multi-tenant — varia por Conta):**
```sql
create table schema.nome_tabela(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
    conta_id integer not null references adm.contas,
    id integer not null,
	descricao varchar(100) not null,
    primary key (conta_id, id),
    constraint nome_tabela_idkey unique(id),
	constraint nome_tabela_ukey unique(conta_id, descricao)
);
```

**3. Grants da tabela principal**
```sql
grant select, insert, update, delete on schema.nome_tabela to sgisis;
grant select, insert, update, delete on schema.nome_tabela to sgitec;
grant select on schema.nome_tabela to consulta;
```

**4. Cabeçalho da tabela de auditoria**
```sql
/******************************************************************************************
 * TABELA: audit.schema_nome_tabela
 */
```

**5. Tabela de auditoria**

Nome: `audit.{schema}_{nome_tabela}` (ex: `audit.adm_planos`).
Campos: os três de auditoria obrigatórios primeiro, depois SOMENTE os campos de negócio
da tabela principal — sem os campos created_by, created_at, updated_by, updated_at, deleted_by:
```sql
create table audit.schema_nome_tabela (
    usuario_audit varchar(50) default current_user not null,
    oper_audit audit.enum_oper_audit default 'I' not null,
    dh_audit timestamp(0) default current_timestamp not null,
    conta_id integer not null,     -- somente se a tabela for multi-tenant
    id integer not null,
    descricao varchar(100) not null
    -- demais campos de negócio, sem constraints
);
```

**6. Índices da tabela de auditoria**
```sql
create index schema_nome_tabela_idx1 on audit.schema_nome_tabela(dh_audit,oper_audit,usuario_audit);
create index schema_nome_tabela_idx2 on audit.schema_nome_tabela(dh_audit,usuario_audit,oper_audit);
```

**7. Grants da tabela de auditoria**
```sql
grant select, insert on audit.schema_nome_tabela to sgisis;
grant select on audit.schema_nome_tabela to sgitec;
grant select on audit.schema_nome_tabela to consulta;
```

**8. Trigger de geração automática do id (somente tabelas COM conta_id)**
```sql
/******************************************************************************************
 * Criação da trigger para geração automática do id
 */
create trigger id_bi before insert on schema.nome_tabela for each row execute function adm.func_id_before();
```
`adm.func_id_before()` gera o `id` via UPSERT em `adm.contas_sequencias` (contador serializado por
`conta_id` + nome da tabela) — seguro sob inserts concorrentes na mesma conta, ao contrário do
`MAX(id)+1` usado no Sigein original.

**9. Cabeçalho das triggers de auditoria**
```sql
/******************************************************************************************
 * Criação das triggers para audit
 */
```

**10. As 5 triggers de auditoria (sempre estas mesmas)**
```sql
create trigger audit_bi before insert on schema.nome_tabela for each row execute function audit.func_audit_before();
create trigger audit_bu before update on schema.nome_tabela for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on schema.nome_tabela for each row execute function audit.func_audit_after();
create trigger audit_au after update on schema.nome_tabela for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on schema.nome_tabela for each row execute function audit.func_audit_after();
```

## Ao final do script, informe

- O nome sugerido para o arquivo Flyway: `V{YYYYMMDDHHMM}__criar_tabela_{nome_tabela}.sql`
  Use a data e hora atuais no formato `YYYYMMDDHHmm`.
- Lembre o usuário de salvar o arquivo em `Scripts/` e executar o Flyway para aplicar a migração.
