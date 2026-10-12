# Schema `radar` — separar as tabelas do Radar de Licitações do espelho `pncp`

Data: 2026-10-12

## Objetivo

O schema `pncp` foi criado para conter apenas o espelho dos dados públicos (dados globais,
sem divisão por conta/empresa), mas acumulou todas as tabelas de negócio do Radar de
Licitações (módulo 97). Esta mudança devolve ao `pncp` só o espelho e move o restante para
um novo schema `radar`.

Critério de classificação: **espelho de fonte pública** (PNCP ou Comprasnet), global e
compartilhado entre contas, fica em `pncp`. Todo o resto do produto Radar vai para `radar`,
mesmo que não tenha `conta_id` (ex.: `alertas_operacionais`, preferências de notificação).

Sucesso:
- `pncp` com exatamente 7 tabelas espelho; `radar` com as 11 tabelas do Radar.
- Dados, constraints, FKs, triggers, grants e auditoria preservados e funcionando.
- Resumo de mudanças entregue para o agente programador ajustar o `radar_licitacoes`.

## Classificação

| Fica em `pncp` | Vai para `radar` |
|---|---|
| `orgaos` | `empresas` |
| `orgaos_unidades` | `empresas_usuarios` |
| `contratacoes` | `empresas_contratacoes` |
| `contratacoes_itens` | `boletins` |
| `contratacoes_itens_resultados` | `boletins_edicoes` |
| `contratacoes_arquivos` | `boletins_edicoes_itens` |
| `contratacoes_mensagens` | `boletins_notificacoes` |
| | `boletins_visualizacoes` |
| | `notificacoes_enviadas` |
| | `usuarios_preferencas_notificacao` -> **`preferencias_notificacoes`** |
| | `alertas_operacionais` |

`contratacoes_mensagens` (chat do Comprasnet) fica em `pncp`: é espelho de dado público,
global por contratação.

## Estratégia de deploy

Script único, aplicado junto com o deploy do código novo do `radar_licitacoes` (sem views
de compatibilidade). Entre a aplicação da migration e a subida do código novo, o código
antigo fica quebrado — janela aceita.

## O script

Arquivo: `Scripts/V202610121100__criar_schema_radar_mover_tabelas_pncp.sql` (uma transação).

Mecanismo: `alter table ... set schema radar` — só metadados, sem cópia de dados; leva junto
índices, constraints, FKs, triggers, grants e as sequences `serial` (owned by).

1. **Schema `radar`**: `create schema radar`, `comment on schema`, `grant usage` para
   `sgisis`, `sgitec`, `consulta`.
2. **Mover as 11 tabelas.** Para cada `X`:
   - `alter table pncp.X set schema radar;`
   - `alter table audit.pncp_X rename to radar_X;` — obrigatório, pois
     `audit.func_audit_after()` resolve a tabela audit por
     `TG_TABLE_SCHEMA || '_' || TG_TABLE_NAME`;
   - `alter index audit.pncp_X_idx1 rename to radar_X_idx1;` (idem `_idx2`).
3. **Renomear `radar.usuarios_preferencas_notificacao` -> `radar.preferencias_notificacoes`**,
   com renomeação de:
   - constraints: `usuarios_preferencas_notificacao_pkey` -> `preferencias_notificacoes_pkey`,
     `_canal_chk` -> `preferencias_notificacoes_canal_chk`,
     `_tipo_sinal_chk` -> `preferencias_notificacoes_tipo_sinal_chk`,
     `_usuario_login_fkey` -> `preferencias_notificacoes_usuario_login_fkey`;
   - tabela audit: `audit.radar_preferencias_notificacoes`, índices
     `radar_preferencias_notificacoes_idx1/2`.
4. **Tabelas audit órfãs** (tabelas de negócio já dropadas) renomeadas de `audit.pncp_*` para
   `audit.radar_*`, com seus índices:
   `contas_contratacoes`, `empresas_mencoes`, `mencoes_notificacoes_enviadas`,
   `contratacoes_mensagens_mencoes`.
5. **`pncp.contratacoes_mensagens.dados_json`** (removido em `V202610021300`, inclusive da
   audit — não há dado a recuperar):
   - `add column dados_json jsonb not null default '{}'` (preenche as linhas existentes);
   - `alter column dados_json drop default` — o código passa a ser obrigado a gravar o payload;
   - `audit.pncp_contratacoes_mensagens`: `add column dados_json jsonb null`;
   - comentário da coluna. Sem índice GIN (não há consulta que precise).
6. **Comentários**: atualizar `comment on schema pncp` (espelho de dados públicos PNCP/
   Comprasnet) e `comment on table pncp.contratacoes` (hoje cita o Radar).

Regras do repositório: só caracteres WIN1252 (usar `->`, nunca setas Unicode).

FKs cruzadas resultantes (válidas, sem alteração): `radar.empresas_contratacoes ->
pncp.contratacoes`, `radar.notificacoes_enviadas -> pncp.contratacoes_mensagens`,
`radar.empresas -> adm.contas`, várias `radar.* -> adm.usuarios`.

## Verificação local

Antes: snapshot de `count(*)` de cada tabela a mover. Depois de `docker compose restart flyway`:
- `flyway_schema_history`: nova versão com `success = true`.
- Contagens iguais ao snapshot.
- `pncp` com 7 tabelas, `radar` com 11; nenhuma `audit.pncp_*` além das 7 espelho.
- Auditoria (em transação com rollback): `insert`/`update` em `radar.empresas` e
  `radar.preferencias_notificacoes` gera linha em `audit.radar_*`; insert em
  `pncp.contratacoes_mensagens` sem `dados_json` falha e com `dados_json` grava em audit.
- Grants: `has_schema_privilege` (usage em `radar`), `has_table_privilege` e
  `has_sequence_privilege` para `sgisis`/`sgitec`/`consulta` nas tabelas e sequences de `radar`.

## Documentação

`CLAUDE.md`, seção "Arquitetura de schemas": acrescentar `pncp` (espelho de dados públicos
PNCP/Comprasnet, global, sem tenant) e `radar` (negócio do Radar de Licitações, módulo 97),
com a regra: tabela nova do Radar vai em `radar`, nunca em `pncp`.

## Resumo para o agente programador (entregue no chat ao final)

- De/para dos nomes qualificados das 11 tabelas (incluindo o rename de preferências).
- Constraints renomeadas (relevante para `ON CONFLICT ON CONSTRAINT` ou tratamento de erro
  por nome).
- Sequences mudam de schema mantendo o nome: `radar.empresas_id_seq`,
  `radar.boletins_id_seq`, `radar.boletins_edicoes_id_seq`.
- O que não muda: as 7 tabelas de `pncp`, colunas, FKs.
- `pncp.contratacoes_mensagens.dados_json` obrigatório (`jsonb not null`, sem default).
- Tabelas audit renomeadas (`audit.pncp_X` -> `audit.radar_X`).
- Deploy coordenado: migration e código novo sobem juntos.
- Revisar no `radar_licitacoes`: referências mortas a tabelas já dropadas
  (`pncp.contratacoes_mensagens_mencoes`, `pncp.empresas_mencoes`, `pncp.contas_contratacoes`,
  `pncp.mencoes_notificacoes_enviadas`, `pncp.comprasnet_sessoes`) e a declaração de schema
  `pncp` em entidades/mappers.

## Fora de escopo

- Views de compatibilidade (descartadas — deploy coordenado).
- Backfill real de `dados_json` (responsabilidade da aplicação).
- Alterar o repositório `pncp` (ingestor), que só usa tabelas espelho.
