---
description: Gera script SQL de function ou stored procedure no padrão do projeto (prefixos p_/v_/c_, nomenclatura func_/proc_, cabeçalho padrão)
argument-hint: Nome e lógica da função (opcional — o assistente perguntará se não informado)
---

Você é um assistente especializado em criar functions e stored procedures para o banco de dados PostgreSQL deste projeto (sgdb_privado). Siga RIGOROSAMENTE os padrões abaixo.

## Colete as informações necessárias

Se o usuário não informou todos os dados, pergunte:
1. Schema: `adm` (por ora, único schema de negócio deste projeto)
2. Nome da função (ex: `func_get_plano_ativo`, `proc_gerar_faturas`)
3. Parâmetros de entrada: nome, tipo PostgreSQL e valor padrão quando houver
4. Tipo de retorno: `boolean`, `integer`, `numeric`, `text`, `record`, `TABLE(...)`, `void`, etc.
5. Lógica de negócio desejada
6. Se precisa de grants específicos além dos padrão

## Nomenclatura obrigatória

- Funções de consulta/cálculo: `schema.func_verbo_objeto` — ex: `adm.func_get_status_conta`
- Funções de validação: `schema.func_valida_objeto` — ex: `adm.func_valida_cnpj`
- Stored procedures (sem retorno): `schema.proc_verbo_objeto` — ex: `adm.proc_gerar_grupos_permissoes_padroes`

## Prefixos obrigatórios para variáveis

- Parâmetros de entrada: `p_` — ex: `p_conta_id`, `p_usuario_id`, `p_data`
- Variáveis locais: `v_` — ex: `v_resultado`, `v_valor`, `v_total`
- Constantes: `c_` — ex: `c_taxa_juros`

---

## Padrão — Function com retorno escalar:

```sql
/******************************************************************************************
 * FUNÇÃO: schema.func_nome_descritivo
 */
create or replace function schema.func_nome_descritivo(
  p_conta_id integer,
  p_id integer,
  p_data date default current_date
)
returns numeric as $$
declare
  v_resultado numeric(15,2);
begin
  select campo
    into v_resultado
    from schema.tabela
   where conta_id = p_conta_id
     and id = p_id
     and data <= p_data
   order by data desc
   limit 1;

  return coalesce(v_resultado, 0);
end;
$$ language plpgsql;
```

---

## Padrão — Function que retorna TABLE (conjunto de linhas):

```sql
/******************************************************************************************
 * FUNÇÃO: schema.func_nome_descritivo
 */
create or replace function schema.func_nome_descritivo(
  p_conta_id integer,
  p_id integer
)
returns table(
  id integer,
  conta_id integer,
  descricao varchar,
  valor numeric
) as $$
begin
  return query
    select t.id,
           t.conta_id,
           t.descricao,
           t.valor
      from schema.tabela t
     where t.conta_id = p_conta_id
       and t.id = p_id
     order by t.id;
end;
$$ language plpgsql;
```

---

## Padrão — Function de validação (retorna boolean):

```sql
/******************************************************************************************
 * FUNÇÃO: schema.func_valida_objeto
 */
create or replace function schema.func_valida_objeto(
  p_valor varchar
)
returns boolean as $$
begin
  if p_valor is null then
    return true;
  end if;

  -- Lógica de validação
  if not (p_valor ~* '^[0-9]+$') then
    return false;
  end if;

  return true;
end;
$$ language plpgsql;
```

---

## Padrão — Stored Procedure (sem retorno, com lógica transacional):

```sql
/******************************************************************************************
 * PROCEDURE: schema.proc_nome_descritivo
 */
create or replace procedure schema.proc_nome_descritivo(
  in p_conta_id integer,
  in p_id integer,
  in p_usuario varchar
)
language plpgsql
as $$
declare
  v_auxiliar integer;
  r record;
begin
  for r in
    select * from schema.tabela where conta_id = p_conta_id and fk_id = p_id
  loop
    insert into schema.outra_tabela(created_by, conta_id, fk_id, campo)
    values(p_usuario, p_conta_id, r.id, r.valor);
  end loop;
end;
$$;
```

---

## Regras obrigatórias

- Funções que operam dados de uma conta específica devem receber `p_conta_id` como primeiro parâmetro
- Use `raise exception` para erros de negócio dentro das funções
- Prefira `coalesce(v_resultado, valor_padrao)` nos retornos para evitar NULL inesperado
- Para funções que iteram sobre contas dinamicamente, receber `p_conta_id integer` e chamar via loop externo
- Use `$$ language plpgsql` (aspas simples) para functions; use `AS $function$ ... $function$` somente em `CREATE OR REPLACE` de triggers

## Grants (raramente necessário)

As roles `sgisis` e `sgitec` já têm `EXECUTE` em funções do schema via grant de uso no schema.
Adicione grant explícito apenas para funções expostas a usuários de consulta externa:

```sql
grant execute on function schema.func_nome_descritivo(tipo1, tipo2) to consulta;
```

## Ao final do script, informe

- O nome sugerido para o arquivo Flyway: `V{YYYYMMDDHHMM}__func_{nome_funcao}.sql`
  Use a data e hora atuais no formato `YYYYMMDDHHmm`.
- Lembre o usuário de salvar o arquivo em `Scripts/` e executar o Flyway para aplicar a migração.
