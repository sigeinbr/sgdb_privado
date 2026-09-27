/******************************************************************************************
 * TABELA: pncp.mencoes_notificacoes_enviadas
 *
 * Substitui pncp.contratacoes_mensagens_mencoes.email_enviado_em para o controle de
 * reenvio: uma linha por (menção, usuário, canal) confirmando que a entrega já ocorreu.
 * `canal` aqui é o canal efetivamente usado na entrega, não o preferido — um fallback de
 * WhatsApp para e-mail grava canal = 'email', pois o que importa para impedir reenvio é o
 * que já foi entregue de fato. A "menção" (conta_id, mensagem_id) não tem coluna id
 * própria — sua PK real já é essa dupla, referenciada aqui como FK composta.
 */
create table pncp.mencoes_notificacoes_enviadas(
	created_by varchar(50) default current_user not null,
	created_at timestamp(0) default current_timestamp not null,
	updated_by varchar(50) default current_user not null,
	updated_at timestamp(0) default current_timestamp not null,
	deleted_by varchar(50) null,
	conta_id integer not null,
	mensagem_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,

	enviado_em timestamp(0) not null,

	constraint mencoes_notificacoes_enviadas_pkey primary key (conta_id, mensagem_id, usuario_login, canal),
	constraint mencoes_notificacoes_enviadas_mencao_fkey foreign key (conta_id, mensagem_id) references pncp.contratacoes_mensagens_mencoes (conta_id, mensagem_id) on delete cascade,
	constraint mencoes_notificacoes_enviadas_usuario_login_fkey foreign key (usuario_login) references adm.usuarios (login) on delete cascade,
	constraint mencoes_notificacoes_enviadas_canal_chk check (canal in ('email','whatsapp'))
);
comment on column pncp.mencoes_notificacoes_enviadas.canal is 'canal efetivamente usado na entrega, não o preferido';

grant select, insert, update, delete on pncp.mencoes_notificacoes_enviadas to sgisis;
grant select, insert, update, delete on pncp.mencoes_notificacoes_enviadas to sgitec;
grant select on pncp.mencoes_notificacoes_enviadas to consulta;

/******************************************************************************************
 * TABELA: audit.pncp_mencoes_notificacoes_enviadas
 */
create table audit.pncp_mencoes_notificacoes_enviadas (
	usuario_audit varchar(50) default current_user not null,
	oper_audit audit.enum_oper_audit default 'I' not null,
	dh_audit timestamp(0) default current_timestamp not null,
	conta_id integer not null,
	mensagem_id integer not null,
	usuario_login varchar(50) not null,
	canal varchar(10) not null,
	enviado_em timestamp(0) not null
);

create index pncp_mencoes_notificacoes_enviadas_idx1 on audit.pncp_mencoes_notificacoes_enviadas(dh_audit,oper_audit,usuario_audit);
create index pncp_mencoes_notificacoes_enviadas_idx2 on audit.pncp_mencoes_notificacoes_enviadas(dh_audit,usuario_audit,oper_audit);

grant select, insert on audit.pncp_mencoes_notificacoes_enviadas to sgisis;
grant select on audit.pncp_mencoes_notificacoes_enviadas to sgitec;
grant select on audit.pncp_mencoes_notificacoes_enviadas to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on pncp.mencoes_notificacoes_enviadas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on pncp.mencoes_notificacoes_enviadas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert  on pncp.mencoes_notificacoes_enviadas for each row execute function audit.func_audit_after();
create trigger audit_au after update  on pncp.mencoes_notificacoes_enviadas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete  on pncp.mencoes_notificacoes_enviadas for each row execute function audit.func_audit_after();

/******************************************************************************************
 * Backfill: para cada menção já com email_enviado_em preenchido, registra a entrega para
 * cada usuário vinculado à conta da menção (via grupos_permissoes_usuarios), com
 * canal = 'email'. Só depois deste backfill a coluna
 * pncp.contratacoes_mensagens_mencoes.email_enviado_em pode ser aposentada — sem ele, o
 * primeiro ciclo do novo pipeline reenviaria por e-mail todo o histórico já entregue.
 */
insert into pncp.mencoes_notificacoes_enviadas (conta_id, mensagem_id, usuario_login, canal, enviado_em)
select distinct
	m.conta_id,
	m.mensagem_id,
	gpu.usuario_login,
	'email',
	m.email_enviado_em
from pncp.contratacoes_mensagens_mencoes m
join adm.grupos_permissoes gp on (gp.conta_id = m.conta_id)
join adm.grupos_permissoes_usuarios gpu on (gpu.grupo_permissao_id = gp.id)
where m.email_enviado_em is not null
on conflict do nothing;
