---
description: Gera script SQL de trigger de negócio (BIU/AIU/AIUD) no padrão do projeto — validações e lógica de negócio, não triggers de auditoria
argument-hint: Tabela e tipo da trigger (opcional — o assistente perguntará se não informado)
---

Você é um assistente especializado em criar triggers de negócio para o banco de dados PostgreSQL deste projeto (sgdb_privado). Siga RIGOROSAMENTE os padrões abaixo.

**Importante:** as triggers de AUDITORIA (audit_bi, audit_bu, audit_ai, audit_au, audit_ad) são geradas automaticamente pela skill `/criar-tabela`. Esta skill cria apenas triggers de NEGÓCIO (validações e lógica de negócio).

## Colete as informações necessárias

Se o usuário não informou todos os dados, pergunte:
1. Schema e nome da tabela (ex: `adm.contas_modulos`)
2. Tipo da trigger:
   - **BIU** — `BEFORE INSERT OR UPDATE`: validações antes de gravar
   - **AIU** — `AFTER INSERT OR UPDATE`: lógica de negócio após gravar
   - **AIUD** — `AFTER INSERT OR UPDATE OR DELETE`: lógica completa incluindo delete
   - **AU** — `AFTER UPDATE`: somente na atualização
   - **BI** — `BEFORE INSERT`: somente na inserção
3. A lógica de negócio desejada: validações, atualizações em outras tabelas, etc.
4. Se a trigger precisa de variáveis auxiliares (record para loop, campos numéricos, etc.)

## Gere o script SQL completo no padrão do projeto

### Nomenclatura obrigatória

- **Função:** `schema.trg_nome_tabela_tipo` — ex: `adm.trg_contas_modulos_aiu`
- **Trigger:** `nome_tabela_tipo` — ex: `contas_modulos_aiu`

---

### Padrão BIU — validação antes de gravar:

```sql
/******************************************************************************************
 * Function: schema.trg_nome_tabela_biu
 */
CREATE OR REPLACE FUNCTION schema.trg_nome_tabela_biu()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.campo is null then
    raise exception 'Deve ser informado o campo para o registro %.', new.identificacao;
  end if;

  if new.campo_a > new.campo_b then
    raise exception 'O campo_a não pode ser maior que campo_b para o registro %.', new.identificacao;
  end if;

  return new;
end;
$function$;
create trigger nome_tabela_biu before insert or update on schema.nome_tabela for each row execute function schema.trg_nome_tabela_biu();
```

---

### Padrão AIU — lógica de negócio após gravar (com loop em registros relacionados):

```sql
/******************************************************************************************
 * Function: schema.trg_nome_tabela_aiu
 */
CREATE OR REPLACE FUNCTION schema.trg_nome_tabela_aiu()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare 
  r record;
begin
  for r in 
    select * from schema.tabela_relacionada where conta_id = new.conta_id and fk_id = new.id
  loop 
    if new.data < r.data_referencia then
      raise exception 'Não é permitido realizar operação com data anterior à data de referência do registro (%).', r.identificacao;
    end if;

    update schema.outra_tabela
      set updated_by = new.updated_by,
          campo = novo_valor
    where conta_id = new.conta_id and id = r.id;
  end loop;

  return new;
end;
$function$;
create trigger nome_tabela_aiu after insert or update on schema.nome_tabela for each row execute function schema.trg_nome_tabela_aiu();
```

---

### Padrão AIUD — lógica completa incluindo delete:

```sql
/******************************************************************************************
 * Function: schema.trg_nome_tabela_aiud
 */
CREATE OR REPLACE FUNCTION schema.trg_nome_tabela_aiud()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- Ignorar validações durante migração de dados
  if (current_setting('sis.migracao', true) = 'true') then
    return new;
  end if;

  if new.data > current_date then
    raise exception 'Não é permitido data futura.';
  end if;

  if (
    exists (
      select 1
      from schema.tabela_relacionada
      where conta_id = coalesce(new.conta_id, old.conta_id)
        and fk_id = coalesce(new.fk_id, old.fk_id)
        and data > coalesce(new.data, old.data)
    )
  ) then
    raise exception
      'Não é permitido movimentação pois existe registro com data posterior para o item (%).',
      (
        select identificacao
        from schema.tabela_principal
        where conta_id = coalesce(new.conta_id, old.conta_id)
          and id = coalesce(new.fk_id, old.fk_id)
        limit 1
      );
  end if;

  return new;
end;
$function$;
create trigger nome_tabela_aiud after insert or update or delete on schema.nome_tabela for each row execute function schema.trg_nome_tabela_aiud();
```

---

## Regras obrigatórias

- Use `raise exception` para todos os erros de negócio
- Mensagens de erro devem identificar o registro afetado: `'Mensagem para o bem (%).', new.identificacao`
- Para ignorar validações em migração de dados: `if (current_setting('sis.migracao', true) = 'true') then return new; end if;`
- Delete lógico via sistema: verificar `current_user = 'sgisis'` e usar `deleted_by` em vez de DELETE físico
- Triggers BEFORE retornam `new`; triggers AFTER também retornam `new` (em DELETE retornam `old`)
- Em triggers AIUD use `coalesce(new.campo, old.campo)` para compatibilidade com DELETE
- Para desfazer efetivação: se `current_user = 'sgisis'`, usar `update ... set deleted_by = ...`; caso contrário usar `delete from ...`

## Ao final do script, informe

- O nome sugerido para o arquivo Flyway: `V{YYYYMMDDHHMM}__trg_{nome_tabela}_{tipo}.sql`
  Use a data e hora atuais no formato `YYYYMMDDHHmm`.
- Lembre o usuário de salvar o arquivo em `Scripts/` e executar o Flyway para aplicar a migração.
