/******************************************************************************************
 * pncp.notificacoes_enviadas: adiciona destinatario
 *
 * Hoje o painel reconstrói o destinatário exibido no popup "Notificações enviadas" via
 * join com adm.usuarios (usuario_login), e mostra o login nas duas colunas -- coincide
 * com o email, mas está errado para WhatsApp (deveria ser o telefone). Além disso,
 * adm.usuarios.email/telefone são mutáveis: reconstruir por join faz o histórico mudar se
 * o usuário trocar e-mail/telefone depois. destinatario grava o valor efetivamente usado
 * no envio (email quando canal = 'email', telefone quando canal = 'whatsapp'),
 * congelado no momento do INSERT.
 *
 * varchar(150) para acompanhar adm.usuarios.email (o mais longo dos dois formatos
 * possíveis; telefone cabe folgado em 20).
 */
alter table pncp.notificacoes_enviadas
    add column destinatario varchar(150) null;

alter table audit.pncp_notificacoes_enviadas
    add column destinatario varchar(150) null;

comment on column pncp.notificacoes_enviadas.destinatario is 'email ou telefone efetivamente usado no envio, congelado no momento do envio -- não reconstruir por join com adm.usuarios, que é mutável';

/******************************************************************************************
 * Backfill (melhor esforço): o valor realmente usado em envios passados não é
 * recuperável, só o email/telefone atual do login. Poucas dezenas de linhas.
 */
update pncp.notificacoes_enviadas ne
   set destinatario = case ne.canal
                         when 'email'    then u.email
                         when 'whatsapp' then u.telefone
                       end
  from adm.usuarios u
 where u.login = ne.usuario_login
   and ne.destinatario is null;

/******************************************************************************************
 * Confirma que o backfill cobriu 100% das linhas antes de travar not null -- aborta a
 * migration em vez de deixar a coluna com nulos (ex.: usuário com canal = 'whatsapp' mas
 * sem telefone cadastrado hoje).
 */
do $$
declare
    v_pendentes integer;
begin
    select count(*) into v_pendentes
      from pncp.notificacoes_enviadas
     where destinatario is null;

    if v_pendentes > 0 then
        raise exception 'pncp.notificacoes_enviadas: % linha(s) sem destinatario após backfill (usuário sem email/telefone cadastrado para o canal) -- resolver antes de aplicar not null', v_pendentes;
    end if;
end $$;

alter table pncp.notificacoes_enviadas
    alter column destinatario set not null;
