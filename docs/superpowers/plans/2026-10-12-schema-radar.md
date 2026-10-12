# Schema radar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mover as 11 tabelas do Radar de `pncp` para o novo schema `radar`, deixando em `pncp` só as 7 tabelas espelho, e entregar o resumo das mudanças ao agente programador.

**Architecture:** Uma única migration Flyway usando `alter table ... set schema` (só metadados) + rename das tabelas audit correspondentes, rename de `usuarios_preferencas_notificacao`, restauração de `pncp.contratacoes_mensagens.dados_json`. Verificação por consultas SQL no banco local antes/depois.

**Tech Stack:** PostgreSQL 15, Flyway (docker compose), psql via `docker exec postgres-sigein`.

**Spec:** `docs/superpowers/specs/2026-10-12-schema-radar-design.md`

## Global Constraints

- Nome do arquivo: `Scripts/V202610121100__criar_schema_radar_mover_tabelas_pncp.sql`.
- Só caracteres WIN1252 no script, inclusive comentários (usar `->`, nunca setas Unicode).
- Nunca editar script já aplicado; o arquivo novo é o único script tocado.
- Grants de schema para os três roles: `sgisis`, `sgitec`, `consulta`.
- `audit.func_audit_after()` resolve a audit por `TG_TABLE_SCHEMA || '_' || TG_TABLE_NAME` -> toda tabela movida exige `audit.pncp_X` renomeada para `audit.radar_X` no mesmo script.
- Atalho psql usado abaixo: `PSQL="docker exec postgres-sigein psql -U sgidba -d target -v ON_ERROR_STOP=1"`.

## Review Focus

- Tabela audit não renomeada -> insert em `radar.X` falha com "relation audit.radar_X does not exist". Coberto pelo teste de auditoria da Task 1 para `radar.empresas` e `radar.preferencias_notificacoes`; o check de inventário (nenhuma `audit.pncp_*` além das 7) cobre as demais.
- Sequences `serial` sem `usage` para `sgisis` após mover -> insert da aplicação falha. Coberto pelo check `has_sequence_privilege`.
- `sgisis` sem `usage` no schema `radar` -> toda query da aplicação falha com "permission denied for schema radar". Coberto pelo check `has_schema_privilege`.
- Caractere fora do WIN1252 em comentário derruba a migration. Coberto por `iconv` no Step 3.
- Dados perdidos no move. Coberto pela comparação de contagens com o snapshot.

---

### Task 1: Migration de criação do schema radar

**Files:**
- Create: `Scripts/V202610121100__criar_schema_radar_mover_tabelas_pncp.sql`
- Scratch (não versionar): `$SCRATCH/verificar_radar.sql`, `$SCRATCH/snapshot_antes.txt` (`$SCRATCH` = diretório de scratchpad da sessão)

**Interfaces:**
- Produces: schema `radar` com as 11 tabelas; `radar.preferencias_notificacoes`; `audit.radar_*` (15 tabelas: 11 movidas + 4 órfãs); `pncp.contratacoes_mensagens.dados_json jsonb not null` sem default; `audit.pncp_contratacoes_mensagens.dados_json jsonb null`.

- [ ] **Step 1: Snapshot das contagens antes**

Gerar e salvar em `$SCRATCH/snapshot_antes.txt` o resultado de `select 'X', count(*) from pncp.X` para cada uma das 11 tabelas a mover (union all, ordenado pelo nome).

- [ ] **Step 2: Escrever `$SCRATCH/verificar_radar.sql` e rodar — deve falhar**

O script roda em `begin; ... rollback;` e cada checagem é um `do $$ ... $$` que dá `raise exception` se falhar:

```sql
-- inventário
assert (select count(*) from information_schema.tables where table_schema='pncp') = 7;
assert (select count(*) from information_schema.tables where table_schema='radar') = 11;
assert (select count(*) from information_schema.tables where table_schema='audit' and table_name like 'pncp\_%') = 7;
assert (select count(*) from information_schema.tables where table_schema='audit' and table_name like 'radar\_%') = 15;
assert to_regclass('radar.preferencias_notificacoes') is not null;
assert to_regclass('audit.radar_preferencias_notificacoes') is not null;
assert (select count(*) from pg_constraint where conrelid='radar.preferencias_notificacoes'::regclass and conname like 'preferencias_notificacoes\_%') = 4;
-- grants, para cada r in (sgisis, sgitec, consulta)
assert has_schema_privilege(r, 'radar', 'usage');
assert has_table_privilege(r, 'radar.<cada tabela>', 'select');           -- todas as 11
assert has_table_privilege('sgisis', 'radar.<cada tabela>', 'insert');    -- e sgitec
assert has_sequence_privilege(r2, 'radar.<seq>', 'usage');                -- r2 in (sgisis, sgitec); seqs: empresas_id_seq, boletins_id_seq, boletins_edicoes_id_seq
-- auditoria no schema novo
-- insert em radar.empresas (colunas obrigatórias: ver \d radar.empresas, usar conta_id existente) -> exists em audit.radar_empresas com oper_audit='I'
-- insert em radar.preferencias_notificacoes (usuario_login existente, 'boletim', 'email', true) -> exists em audit.radar_preferencias_notificacoes
-- dados_json
-- insert em pncp.contratacoes_mensagens sem dados_json -> deve levantar not_null_violation (capturar com exception when not_null_violation)
-- insert com dados_json '{"a":1}' -> exists em audit.pncp_contratacoes_mensagens com dados_json = '{"a":1}'
assert (select count(*) from pncp.contratacoes_mensagens where dados_json is null) = 0;
```

Também comparar `count(*)` atual das 11 tabelas (agora em `radar`) com `snapshot_antes.txt` (diff no shell).

Run: `$PSQL -f - < $SCRATCH/verificar_radar.sql`
Expected: FAIL na primeira assertion de inventário.

- [ ] **Step 3: Escrever a migration**

Seguir a seção "O script" da spec, itens 1–6, nessa ordem, com o cabeçalho `/*** ... */` no estilo de [V202610021300](../../../Scripts/V202610021300__pncp_remover_dados_replicados_nao_usados.sql) explicando o motivo e que o deploy é coordenado com o `radar_licitacoes`. Valores fixos:
- 11 tabelas: `empresas, empresas_usuarios, empresas_contratacoes, boletins, boletins_edicoes, boletins_edicoes_itens, boletins_notificacoes, boletins_visualizacoes, notificacoes_enviadas, usuarios_preferencas_notificacao, alertas_operacionais`.
- Ordem para preferências: `set schema radar` -> `rename to preferencias_notificacoes` -> `rename constraint` x4 -> `audit.pncp_usuarios_preferencas_notificacao rename to radar_preferencias_notificacoes` -> índices audit `radar_preferencias_notificacoes_idx1/2`.
- 4 órfãs: `contas_contratacoes, empresas_mencoes, mencoes_notificacoes_enviadas, contratacoes_mensagens_mencoes` (+ `_idx1/_idx2`).
- `dados_json`: `add column dados_json jsonb not null default '{}'::jsonb`, depois `alter column dados_json drop default`; audit `add column dados_json jsonb null`; `comment on column` dizendo que é o payload bruto da mensagem na origem.
- Comentário do schema `pncp`: espelho global dos dados públicos (PNCP e Comprasnet), sem tenant e sem regra de negócio. Comentário de `radar`: tabelas de negócio do Radar de Licitações (módulo 97). Comentário de `pncp.contratacoes`: referência local da contratação PNCP; dado completo no banco pncp.

Checar encoding: `iconv -f utf-8 -t windows-1252 Scripts/V202610121100__criar_schema_radar_mover_tabelas_pncp.sql > /dev/null` — sem erro.

- [ ] **Step 4: Aplicar e rodar a verificação — deve passar**

Run: `docker compose restart flyway && docker logs flyway-target 2>&1 | tail -20`
Expected: `Successfully applied 1 migration` (versão 202610121100).
Run: `$PSQL -f - < $SCRATCH/verificar_radar.sql` e o diff das contagens.
Expected: sem exceção, diff vazio.

- [ ] **Step 5: Commit**

```bash
git add Scripts/V202610121100__criar_schema_radar_mover_tabelas_pncp.sql
git commit -m "Radar de Licitacoes - schema radar separado do espelho pncp"
```

### Task 2: Documentar os schemas no CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (seção "Arquitetura de schemas", tabela + parágrafo seguinte)

- [ ] **Step 1: Atualizar a tabela de schemas**

Acrescentar linhas `pncp` (espelho global de dados públicos PNCP/Comprasnet, sem tenant, sem regra de negócio) e `radar` (tabelas de negócio do Radar de Licitações, módulo 97; audit em `audit.radar_*`). Ajustar o parágrafo seguinte: tabela nova do Radar vai em `radar`, nunca em `pncp`. Ajustar a frase "Os demais schemas do Sigein (`comum`, `patrim`, `integracao`, `invent`, `pncp`) não foram copiados" para não contradizer a existência de `pncp`.

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "CLAUDE.md: documentar schemas pncp e radar"
```

### Task 3: Resumo para o agente programador

- [ ] **Step 1: Montar o resumo no chat**

Texto pronto para colar, conforme a seção "Resumo para o agente programador" da spec, com a tabela de/para completa (11 tabelas, constraints renomeadas, sequences, audits) gerada a partir do banco já migrado (`\dt radar.*`, `pg_constraint` de `radar.preferencias_notificacoes`), não de memória.
