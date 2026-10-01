/******************************************************************************************
 * TABELA: audit.whatsapp_mensagens_recebidas
 *
 * Log das mensagens recebidas pelo número do Radar de Licitações (webhook WAHA -> API),
 * uma linha por mensagem processada. Como audit.log_acessos, não é espelho de tabela de
 * negócio: é o próprio registro, escrito diretamente pela aplicação, sem as triggers
 * audit_* nem tabela espelho.
 *
 * - id: id da mensagem no WAHA. A PK é a deduplicação dos reenvios do webhook (a API
 *   trata a violação de whatsapp_mensagens_recebidas_pkey como "já processada").
 * - Sem FK para adm.usuarios de propósito: o log precisa sobreviver à exclusão do
 *   usuário.
 * - resposta NULL = resposta R6 suprimida pelo limite de uma a cada 24h por chat.
 * - sgisis só atualiza resposta_enviada (grant por coluna), marcada após o envio.
 */
create table audit.whatsapp_mensagens_recebidas (
  id                 varchar(128) not null,
  chat_id            varchar(64) not null,
  telefone_resolvido varchar(11) null,
  texto              varchar(1000) null,
  comando            varchar(10) not null,
  usuario_login      varchar(50) null,
  resposta           varchar(2) null,
  resposta_enviada   boolean default false not null,
  recebida_em        timestamp(0) default current_timestamp not null,
  constraint whatsapp_mensagens_recebidas_pkey primary key (id),
  constraint whatsapp_mensagens_recebidas_comando_chk check (comando in ('CADASTRO', 'CANCELAR', 'OUTRO')),
  constraint whatsapp_mensagens_recebidas_resposta_chk check (resposta in ('R1', 'R2', 'R3', 'R4', 'R5', 'R6'))
);

-- limite anti-spam: "houve R6 para este chat_id nas últimas 24h?"
create index whatsapp_mensagens_recebidas_idx1
    on audit.whatsapp_mensagens_recebidas (chat_id, recebida_em)
 where resposta = 'R6';

-- "qual mensagem validou/cancelou este usuário"
create index whatsapp_mensagens_recebidas_idx2
    on audit.whatsapp_mensagens_recebidas (usuario_login, recebida_em)
 where usuario_login is not null;

create index whatsapp_mensagens_recebidas_idx3
    on audit.whatsapp_mensagens_recebidas (recebida_em);

grant select, insert on audit.whatsapp_mensagens_recebidas to sgisis;
grant update (resposta_enviada) on audit.whatsapp_mensagens_recebidas to sgisis;
grant select on audit.whatsapp_mensagens_recebidas to sgitec;
grant select on audit.whatsapp_mensagens_recebidas to consulta;
