/******************************************************************************************
 * Radar de Licitações - período de disputa, fase "aguardando_disputa" e lembrete de disputa
 * (Bloco único, antes do deploy)
 *
 * - pncp.contratacoes: 3 colunas neutras de plataforma (disputa e julgamento)
 * - pncp.contratacoes_leituras_plataforma: última leitura na plataforma de origem (fora da auditoria)
 * - contratacoes_situacao_calculada_chk: aceita 'aguardando_disputa'
 * - radar.preferencias_notificacoes: tipo_sinal aceita 'lembrete_disputa' (coluna ampliada)
 * - radar.lembretes_disputas_enviados: controle de envio do lembrete
 *
 * Aditivo: o código antigo ignora o que é criado.
 *
 * Decisão sobre a última leitura: fica numa tabela 1:1 sem auditoria, e não numa coluna de
 * pncp.contratacoes, porque muda a cada leitura (até a cada 30 min) e cada UPDATE geraria uma
 * linha de audit com a contratação inteira, escondendo as remarcações reais.
 */

/******************************************************************************************
 * pncp.contratacoes - colunas novas (linhas existentes ficam NULL)
 */
alter table pncp.contratacoes
	add column data_disputa_inicio timestamp(0) null,
	add column data_disputa_fim timestamp(0) null,
	add column data_julgamento_inicio timestamp(0) null;

alter table audit.pncp_contratacoes
	add column data_disputa_inicio timestamp(0) null,
	add column data_disputa_fim timestamp(0) null,
	add column data_julgamento_inicio timestamp(0) null;

comment on column pncp.contratacoes.data_disputa_inicio is
  'Início da disputa na plataforma de origem (horário de Brasília). No pregão, abertura da sessão (real ou prevista). Preenchida só pela aplicação.';
comment on column pncp.contratacoes.data_disputa_fim is
  'Fim da disputa na plataforma de origem (horário de Brasília). NULL no pregão, que não tem período de lances.';
comment on column pncp.contratacoes.data_julgamento_inicio is
  'Início do julgamento das propostas: data da mensagem de julgamento iniciado (precisa) ou instante da leitura que o detectou (aproximada).';

/******************************************************************************************
 * TABELA: pncp.contratacoes_leituras_plataforma (sem auditoria, de propósito)
 */
create table pncp.contratacoes_leituras_plataforma(
	contratacao_id integer not null,
	lida_em timestamp(0) default current_timestamp not null,

	constraint contratacoes_leituras_plataforma_pkey primary key (contratacao_id),
	constraint contratacoes_leituras_plataforma_contratacao_fkey
		foreign key (contratacao_id) references pncp.contratacoes (id) on delete cascade
);
comment on table pncp.contratacoes_leituras_plataforma is
  'Instante da última leitura bem-sucedida da contratação na plataforma de origem (horário de Brasília). Sem linha = nunca lida. Sem auditoria: muda a cada leitura.';

grant select, insert, update, delete on pncp.contratacoes_leituras_plataforma to sgisis;
grant select, insert, update, delete on pncp.contratacoes_leituras_plataforma to sgitec;
grant select on pncp.contratacoes_leituras_plataforma to consulta;

/******************************************************************************************
 * pncp.contratacoes - situacao_calculada aceita 'aguardando_disputa'
 */
alter table pncp.contratacoes drop constraint contratacoes_situacao_calculada_chk;
alter table pncp.contratacoes add constraint contratacoes_situacao_calculada_chk
	check (situacao_calculada in (
		'aguardando_abertura',
		'recebendo_propostas',
		'aguardando_disputa',
		'em_disputa',
		'em_julgamento',
		'homologado'
	));

/******************************************************************************************
 * Carga de data_julgamento_inicio (só onde NULL; situacao_calculada não é alterada)
 */
update pncp.contratacoes c
   set data_julgamento_inicio = m.data_hora
  from (
	select contratacao_id, min(data_hora) as data_hora
	  from pncp.contratacoes_mensagens
	 where texto ilike '%etapa de julgamento de propostas foi iniciada%'
	 group by contratacao_id
  ) m
 where m.contratacao_id = c.id
   and c.data_julgamento_inicio is null;

/******************************************************************************************
 * radar.preferencias_notificacoes - tipo_sinal aceita 'lembrete_disputa' (16 caracteres)
 */
alter table radar.preferencias_notificacoes alter column tipo_sinal type varchar(30);
alter table audit.radar_preferencias_notificacoes alter column tipo_sinal type varchar(30);

alter table radar.preferencias_notificacoes drop constraint preferencias_notificacoes_tipo_sinal_chk;
alter table radar.preferencias_notificacoes add constraint preferencias_notificacoes_tipo_sinal_chk
	check (tipo_sinal in ('destinatario', 'cnpj_texto', 'nome_texto', 'prazo_destacado', 'boletim', 'lembrete_disputa'));

/******************************************************************************************
 * TABELA: radar.lembretes_disputas_enviados
 */
create table radar.lembretes_disputas_enviados(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	empresa_id integer not null,
	contratacao_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,
	momento varchar(10) not null,
	data_disputa_inicio timestamp(0) not null,
	destinatario varchar(150) not null,
	enviado_em timestamptz not null,

	constraint lembretes_disputas_enviados_pkey
		primary key (empresa_id, contratacao_id, usuario_login, canal, momento, data_disputa_inicio),
	constraint lembretes_disputas_enviados_canal_chk check (canal in ('email', 'whatsapp')),
	constraint lembretes_disputas_enviados_momento_chk check (momento in ('vespera', '1h')),
	constraint lembretes_disputas_enviados_vinculo_fkey
		foreign key (empresa_id, contratacao_id)
		references radar.empresas_contratacoes (empresa_id, contratacao_id) on delete cascade,
	constraint lembretes_disputas_enviados_usuario_login_fkey
		foreign key (usuario_login) references adm.usuarios (login) on delete cascade
);
comment on table radar.lembretes_disputas_enviados is
  'Lembretes de disputa efetivamente enviados (idempotência do job). data_disputa_inicio na chave: disputa remarcada gera lembretes novos.';

grant select, insert, update, delete on radar.lembretes_disputas_enviados to sgisis;
grant select, insert, update, delete on radar.lembretes_disputas_enviados to sgitec;
grant select on radar.lembretes_disputas_enviados to consulta;

/******************************************************************************************
 * TABELA: audit.radar_lembretes_disputas_enviados
 */
create table audit.radar_lembretes_disputas_enviados (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	empresa_id integer not null,
	contratacao_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,
	momento varchar(10) not null,
	data_disputa_inicio timestamp(0) not null,
	destinatario varchar(150) not null,
	enviado_em timestamptz not null
);

create index radar_lembretes_disputas_enviados_idx1 on audit.radar_lembretes_disputas_enviados(dh_audit,oper_audit,usuario_audit);
create index radar_lembretes_disputas_enviados_idx2 on audit.radar_lembretes_disputas_enviados(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.radar_lembretes_disputas_enviados to sgisis;
grant select on audit.radar_lembretes_disputas_enviados to sgitec;
grant select on audit.radar_lembretes_disputas_enviados to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on radar.lembretes_disputas_enviados for each row execute function audit.func_audit_before();
create trigger audit_bu before update on radar.lembretes_disputas_enviados for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on radar.lembretes_disputas_enviados for each row execute function audit.func_audit_after();
create trigger audit_au after update on radar.lembretes_disputas_enviados for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on radar.lembretes_disputas_enviados for each row execute function audit.func_audit_after();
