/******************************************************************************************
 * privado_initial.sql
 *
 * Migration inicial do banco para empresas privadas (multi-tenant por conta,
 * autoatendimento). Banco novo e isolado do banco público.
 *
 * Adaptado do banco Sigein (setor público / multi-tenant por Unidade Gestora), substituindo
 * o conceito de "Unidade Gestora" (ug_id / adm.ugs) por "Conta" (conta_id / adm.contas),
 * já que este é um produto novo para empresas privadas, com contas criadas via
 * autoatendimento em vez de provisionamento manual.
 *
 * Cobre a estrutura completa dos schemas `adm` e `audit` do Sigein (15 tabelas de negócio +
 * suas 15 tabelas espelho em audit + audit.log_acessos, 6 views, funções e triggers). Os
 * demais schemas (comum/patrim/integracao/invent/pncp) não são copiados. Duas exceções
 * autocontidas do schema `comum` foram portadas para dentro de `adm` — func_valida_cnpj e
 * func_valida_cpf — pois os CHECKs de adm.contas/adm.usuarios dependem delas.
 */


/******************************************************************************************
 * Criação de roles
 *
 * OBS.: As senhas devem ser definidas/alteradas para valores seguros após o deploy, via
 * ALTER USER ... WITH ENCRYPTED PASSWORD '...'. Nenhuma senha real é incluída aqui.
 * `sgidba` é o superuser do container (POSTGRES_USER), não é criado por esta migration.
 */
do $$
begin
  if not exists (select * from pg_catalog.pg_roles where rolname = 'sgitec') then
    create group sgitec;
  end if;
  if not exists (select * from pg_catalog.pg_roles where rolname = 'sgisis') then
    create user sgisis with password 'sgisis';
  end if;
  if not exists (select * from pg_catalog.pg_roles where rolname = 'consulta') then
    create user consulta with password 'sql';
  end if;
end $$;


/******************************************************************************************
 * Criação de schemas
 */
create schema adm;
create schema audit;

grant usage on schema adm to sgisis;
grant usage on schema audit to sgisis;

grant usage on schema adm to sgitec;
grant usage on schema audit to sgitec;

grant usage on schema adm to consulta;
grant usage on schema audit to consulta;


/******************************************************************************************
 * Criação de enums
 */
create type audit.enum_oper_audit as enum ('I', 'A', 'E');
create type adm.enum_tipo_campo as enum ('string', 'integer', 'numeric', 'date', 'sql_list', 'json_list');
create type adm.enum_status_conta as enum ('trial', 'ativo', 'suspenso', 'cancelado');
create type adm.enum_tipo_pessoa as enum ('fisica', 'juridica');
create type adm.enum_tipo_token as enum ('validacao_email', 'recuperacao_senha');


/******************************************************************************************
 * FUNÇÃO: adm.func_valida_cnpj(varchar) / adm.func_valida_cpf(varchar)
 *
 * Portadas do schema `comum` do Sigein (não copiado neste projeto). São autocontidas —
 * sem dependência de nenhum outro schema — por isso movidas para dentro de `adm` em vez
 * de recriar `comum` só por causa delas. Validam dígito verificador (não só formato).
 * Aceitam null (retornam true) e os dois formatos, puro (14/11 dígitos) e com máscara.
 */
create or replace function adm.func_valida_cnpj(p_cnpj character varying)
 returns boolean
 language plpgsql
as $function$
declare
  v_cnpj_invalidos character varying[10]
  default array['00000000000000', '11111111111111',
                '22222222222222', '33333333333333',
                '44444444444444', '55555555555555',
                '66666666666666', '77777777777777',
                '88888888888888', '99999999999999'];

  v_cnpj_quebrado smallint[];

  c_posicao_dv1 constant smallint default 13;
  v_arranjo_dv1 smallint[12] default array[5,4,3,2,9,8,7,6,5,4,3,2];
  v_soma_dv1 smallint default 0;
  v_resto_dv1 double precision default 0;

  c_posicao_dv2 constant smallint default 14;
  v_arranjo_dv2 smallint[13] default array[6,5,4,3,2,9,8,7,6,5,4,3,2];
  v_soma_dv2 smallint default 0;
  v_resto_dv2 double precision default 0;
begin
  if (p_cnpj is null) then
    return true;
  end if;
  if (not (p_cnpj ~* '^([0-9]{14})$' or
           p_cnpj ~* '^([0-9]{2}\.[0-9]{3}\.[0-9]{3}\/[0-9]{4}\-[0-9]{2})$')) or
     p_cnpj = any (v_cnpj_invalidos) or
     p_cnpj is null
  then
    return false;
  end if;

  v_cnpj_quebrado := regexp_split_to_array(regexp_replace(p_cnpj, '[^0-9]', '', 'g'), '');

  for t in 1..12 loop
    v_soma_dv1 := v_soma_dv1 + (v_cnpj_quebrado[t] * v_arranjo_dv1[t]);
  end loop;
  v_resto_dv1 := ((10 * v_soma_dv1) % 11) % 10;

  if (v_resto_dv1 != v_cnpj_quebrado[13]) then
    return false;
  end if;

  for t in 1..13 loop
    v_soma_dv2 := v_soma_dv2 + (v_cnpj_quebrado[t] * v_arranjo_dv2[t]);
  end loop;
  v_resto_dv2 := ((10 * v_soma_dv2) % 11) % 10;

  return v_resto_dv2 = v_cnpj_quebrado[c_posicao_dv2];
end;
$function$;

create or replace function adm.func_valida_cpf(p_cpf character varying)
 returns boolean
 language plpgsql
as $function$
declare
  v_cpf_invalidos character varying[10]
  default array['00000000000', '11111111111',
                '22222222222', '33333333333',
                '44444444444', '55555555555',
                '66666666666', '77777777777',
                '88888888888', '99999999999'];

  v_cpf_quebrado smallint[];

  c_posicao_dv1 constant smallint default 10;
  v_arranjo_dv1 smallint[9] default array[10,9,8,7,6,5,4,3,2];
  v_soma_dv1 smallint default 0;
  v_resto_dv1 double precision default 0;

  c_posicao_dv2 constant smallint default 11;
  v_arranjo_dv2 smallint[10] default array[11,10,9,8,7,6,5,4,3,2];
  v_soma_dv2 smallint default 0;
  v_resto_dv2 double precision default 0;
begin
  if (p_cpf is null) then
    return true;
  end if;
  if (not (p_cpf ~* '^([0-9]{11})$' or
           p_cpf ~* '^([0-9]{3}\.[0-9]{3}\.[0-9]{3}\-[0-9]{2})$')
       ) or
       p_cpf = any (v_cpf_invalidos) or
       p_cpf is null
  then
    return false;
  end if;

  v_cpf_quebrado := regexp_split_to_array(regexp_replace(p_cpf, '[^0-9]', '', 'g'), '');

  for t in 1..9 loop
    v_soma_dv1 := v_soma_dv1 + (v_cpf_quebrado[t] * v_arranjo_dv1[t]);
  end loop;
  v_resto_dv1 := ((10 * v_soma_dv1) % 11) % 10;

  if (v_resto_dv1 != v_cpf_quebrado[c_posicao_dv1]) then
    return false;
  end if;

  for t in 1..10 loop
    v_soma_dv2 := v_soma_dv2 + (v_cpf_quebrado[t] * v_arranjo_dv2[t]);
  end loop;
  v_resto_dv2 := ((10 * v_soma_dv2) % 11) % 10;

  return v_resto_dv2 = v_cpf_quebrado[c_posicao_dv2];
end;
$function$;


/******************************************************************************************
 * FUNÇÃO: adm.func_verifica_sql(text)
 *
 * Bloqueia comandos SQL potencialmente destrutivos em SQL dinâmico informado pelo usuário
 * (ex.: adm.consultas.sql_consulta). Chamada pela camada de aplicação antes de executar.
 */
create or replace function adm.func_verifica_sql(p_comando_sql text)
 returns boolean
 language plpgsql
as $function$
declare
   v_padrao_proibido text[] := array['CREATE', 'DROP', 'ALTER', 'TRUNCATE', 'EXECUTE', 'GRANT', 'REVOKE'];
   v_comando text;
begin
    foreach v_comando in array v_padrao_proibido loop
        if p_comando_sql ~* ('\y' || v_comando || '\y') then
            raise exception 'SQL contém comando proibido: %', v_comando;
        end if;
    end loop;

    return true;
end;
$function$;


/******************************************************************************************
 * FUNÇÃO: audit.func_audit_before()
 *
 * Infraestrutura genérica de auditoria (BEFORE INSERT/UPDATE): estampa created_by/
 * updated_by e ignora updates sem mudança real de dados (diff via jsonb, excluindo as
 * colunas de trilha de auditoria).
 */
create or replace function audit.func_audit_before()
 returns trigger
 language plpgsql
 security definer
as $function$
declare
  v_old_data jsonb;
  v_new_data jsonb;
begin
  case tg_op
    when 'INSERT' then
      new.created_at = current_timestamp;
      new.updated_at = current_timestamp;

      if new.created_by is null then
        new.created_by = session_user;
      end if;

      if new.created_by <> session_user and session_user <> 'sgisis' then
        new.created_by = session_user;
      end if;

      if new.updated_by <> new.created_by then
        new.updated_by = new.created_by;
      end if;

    when 'UPDATE' then
      v_old_data := to_jsonb(old)
        - 'created_by' - 'created_at' - 'updated_by' - 'updated_at';
      v_new_data := to_jsonb(new)
        - 'created_by' - 'created_at' - 'updated_by' - 'updated_at';

      if v_old_data is not distinct from v_new_data then
        return old;
      end if;

      new.created_at = old.created_at;
      new.created_by = old.created_by;
      new.updated_at = current_timestamp;

      if new.updated_by is null then
        new.updated_by = session_user;
      end if;

      if new.updated_by <> session_user and session_user <> 'sgisis' then
        new.updated_by = session_user;
      end if;

    else
      null;
  end case;

  return new;
end;
$function$;


/******************************************************************************************
 * FUNÇÃO: audit.func_audit_after()
 *
 * Infraestrutura genérica de auditoria (AFTER INSERT/UPDATE/DELETE): grava o snapshot em
 * audit.{schema}_{tabela}, resolvido dinamicamente via TG_TABLE_SCHEMA || '_' || TG_TABLE_NAME.
 * O papel `sgisis` nunca deleta fisicamente: preenche `deleted_by`, a trigger audita como
 * operação 'E' e então remove a linha fisicamente. Deletes em cascata originados por uma
 * exclusão lógica do pai são detectados via pg_trigger_depth() e atribuídos ao usuário
 * correto via set_config('audit.cascade_delete_user', ...).
 */
create or replace function audit.func_audit_after()
 returns trigger
 language plpgsql
 security definer
as $function$
declare
  v_current_user varchar(50);
  v_audit_table text;
  v_audit_row jsonb;
  v_old_data jsonb;
  v_new_data jsonb;
begin
  v_current_user := case
    when session_user = 'sgisis' then new.updated_by
    else session_user
  end;

  v_audit_table := tg_table_schema || '_' || tg_table_name;

  case tg_op
    when 'INSERT' then
      v_audit_row := (to_jsonb(new)
        - 'created_by' - 'created_at' - 'updated_by' - 'updated_at' - 'deleted_by')
        || jsonb_build_object('usuario_audit', v_current_user, 'oper_audit', 'I', 'dh_audit', current_timestamp);

      execute format(
        'insert into audit.%I select * from jsonb_populate_record(null::audit.%I, $1)',
        v_audit_table, v_audit_table
      ) using v_audit_row;

    when 'DELETE' then
      if session_user <> 'sgisis' then
        v_audit_row := (to_jsonb(old)
          - 'created_by' - 'created_at' - 'updated_by' - 'updated_at' - 'deleted_by')
          || jsonb_build_object('usuario_audit', v_current_user, 'oper_audit', 'E', 'dh_audit', current_timestamp);

        execute format(
          'insert into audit.%I select * from jsonb_populate_record(null::audit.%I, $1)',
          v_audit_table, v_audit_table
        ) using v_audit_row;
      else
        if old.deleted_by is not null then
          -- delete físico da própria linha após exclusão lógica: auditoria já gravada no UPDATE
          null;
        elsif pg_trigger_depth() > 1 then
          -- delete em cascata originado pelo delete físico de uma linha pai logicamente deletada
          v_current_user := coalesce(
            nullif(current_setting('audit.cascade_delete_user', true), ''),
            session_user
          );
          v_audit_row := (to_jsonb(old)
            - 'created_by' - 'created_at' - 'updated_by' - 'updated_at' - 'deleted_by')
            || jsonb_build_object('usuario_audit', v_current_user, 'oper_audit', 'E', 'dh_audit', current_timestamp);

          execute format(
            'insert into audit.%I select * from jsonb_populate_record(null::audit.%I, $1)',
            v_audit_table, v_audit_table
          ) using v_audit_row;
        else
          raise exception 'Delete nao permitido, usar campo deleted_by.';
        end if;
      end if;

    when 'UPDATE' then
      if new.deleted_by is not null and session_user = 'sgisis' then
        v_audit_row := (to_jsonb(new)
          - 'created_by' - 'created_at' - 'updated_by' - 'updated_at' - 'deleted_by')
          || jsonb_build_object('usuario_audit', new.deleted_by, 'oper_audit', 'E', 'dh_audit', current_timestamp);

        execute format(
          'insert into audit.%I select * from jsonb_populate_record(null::audit.%I, $1)',
          v_audit_table, v_audit_table
        ) using v_audit_row;

        perform set_config('audit.cascade_delete_user', new.deleted_by, true);

        execute format('delete from %I.%I where ctid = $1', tg_table_schema, tg_table_name)
          using new.ctid;

      elsif new.deleted_by is null then
        v_old_data := to_jsonb(old)
          - 'created_by' - 'created_at' - 'updated_by' - 'updated_at' - 'deleted_by';
        v_new_data := to_jsonb(new)
          - 'created_by' - 'created_at' - 'updated_by' - 'updated_at' - 'deleted_by';

        if v_old_data is distinct from v_new_data then
          v_audit_row := v_new_data
            || jsonb_build_object('usuario_audit', v_current_user, 'oper_audit', 'A', 'dh_audit', current_timestamp);

          execute format(
            'insert into audit.%I select * from jsonb_populate_record(null::audit.%I, $1)',
            v_audit_table, v_audit_table
          ) using v_audit_row;
        end if;
      else
        raise exception 'O campo deleted_by nao pode ser alterado.';
      end if;
  end case;

  return new;
end;
$function$;


/******************************************************************************************
 * FUNÇÃO: audit.func_parse_user_agent(text)
 *
 * Faz parsing simples de User-Agent (navegador/SO) para relatórios sobre audit.log_acessos.
 */
create or replace function audit.func_parse_user_agent(p_user_agent text)
 returns table(browser_name text, os_name text)
 language plpgsql
as $function$
begin
  case
    when p_user_agent ~* 'firefox' then browser_name := 'Firefox';
    when p_user_agent ~* 'edg' then browser_name := 'Edge';
    when p_user_agent ~* 'opera' then browser_name := 'Opera';
    when p_user_agent ~* 'msie' then browser_name := 'Internet Explorer';
    when p_user_agent ~* 'chrome' then browser_name := 'Chrome';
    when p_user_agent ~* 'safari' then browser_name := 'Safari';
    else browser_name := 'Desconhecido';
  end case;

  case
    when p_user_agent ~* 'windows' then os_name := 'Windows';
    when p_user_agent ~* 'macintosh|mac os x' then os_name := 'Mac OS X';
    when p_user_agent ~* 'linux' then os_name := 'Linux';
    when p_user_agent ~* 'iphone|ipod' then os_name := 'iOS';
    when p_user_agent ~* 'android' then os_name := 'Android';
    else os_name := 'Desconhecido';
  end case;

  return next;
end;
$function$;


/******************************************************************************************
 * TABELA: adm.usuarios
 *
 * Global (não escopada a uma única conta). Acesso a contas é indireto, via
 * adm.grupos_permissoes_usuarios -> adm.grupos_permissoes.conta_id. Isso já suporta, sem
 * custo extra, um contador/consultor gerenciando várias contas de clientes diferentes.
 */
create table adm.usuarios (
  created_by     varchar(50) default current_user not null,
  created_at     timestamp(0) default current_timestamp not null,
  updated_by     varchar(50) default current_user not null,
  updated_at     timestamp(0) default current_timestamp not null,
  deleted_by     varchar(50) null,
  login          varchar(50) not null,
  nome           varchar(150) not null,
  email          varchar(150) not null,
  senha          text not null,
  cpf            varchar(11) null,
  is_verificado  boolean default false not null,
  constraint usuarios_pkey primary key (login),
  constraint usuarios_email_ukey unique (email),
  constraint usuarios_cpf_ukey unique (cpf),
  constraint usuarios_cpf_chk check (adm.func_valida_cpf(cpf))
);

grant select, insert, update, delete on adm.usuarios to sgisis;
grant select, insert, update, delete on adm.usuarios to sgitec;
grant select on adm.usuarios to consulta;

/******************************************************************************************
 * TABELA: audit.adm_usuarios
 */
create table audit.adm_usuarios (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  login          varchar(50) not null,
  nome           varchar(150) not null,
  email          varchar(150) not null,
  senha          text not null,
  cpf            varchar(11) null,
  is_verificado  boolean not null
);

create index adm_usuarios_idx1 on audit.adm_usuarios (dh_audit, oper_audit, usuario_audit);
create index adm_usuarios_idx2 on audit.adm_usuarios (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_usuarios to sgisis;
grant select on audit.adm_usuarios to sgitec;
grant select on audit.adm_usuarios to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.usuarios for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.usuarios for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.usuarios for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.usuarios for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.usuarios for each row execute function audit.func_audit_after();

/******************************************************************************************
 * Function: adm.trg_usuarios_bu
 *
 * Regras de negócio sobre usuários: login imutável, bloqueia criação de logins "sgitec*",
 * exige que quem edita um usuário tenha acesso de administrador (módulo 1) a todas as
 * contas às quais o usuário editado pertence, invalida verificação de e-mail ao trocar
 * e-mail, e impede exclusão de usuário com grupos de permissão vinculados.
 */
create or replace function adm.trg_usuarios_bu()
 returns trigger
 language plpgsql
as $function$
begin
  if new.login <> old.login then
    raise exception 'Não é permitido alterar o login.';
  end if;
  if new.login like 'sgitec%' then
    raise exception 'Não é permitido criar usuários sgitecs.';
  end if;

  if current_user = 'sgisis' and new.login <> new.updated_by then
    if exists(
      select gp.conta_id
      from adm.grupos_permissoes_usuarios gpu
      join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
      where gpu.usuario_login = new.login
        and gp.conta_id not in (
          select gp.conta_id
          from adm.grupos_permissoes_usuarios gpu
          join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
          where gpu.usuario_login = new.updated_by
            and gp.modulo_id = 1
        )
    ) then
      raise exception 'O usuário % não pode editar o usuário % pois não tem acesso de administrador a todas as contas do mesmo.', new.updated_by, new.login;
    end if;
  end if;

  if new.email <> old.email then
    new.is_verificado = false;
  end if;

  if new.deleted_by is not null then
    if exists(select * from adm.grupos_permissoes_usuarios where usuario_login = new.login) then
      raise exception 'Não é permitido excluir usuários com grupos de permissões vinculados.';
    end if;
  end if;
  return new;
end;
$function$;

create trigger usuarios_bu before update on adm.usuarios for each row execute function adm.trg_usuarios_bu();


/******************************************************************************************
 * TABELA: adm.tokens
 *
 * Tokens de uso único (validação de e-mail, recuperação de senha). Sem FK para usuarios —
 * os parâmetros de identificação (ex.: login) vão dentro de `parametros` (jsonb).
 */
create table adm.tokens (
  created_by   varchar(50) default current_user not null,
  created_at   timestamp(0) default current_timestamp not null,
  updated_by   varchar(50) default current_user not null,
  updated_at   timestamp(0) default current_timestamp not null,
  deleted_by   varchar(50) null,
  id           uuid default gen_random_uuid() not null,
  validade     date default current_date not null,
  tipo         adm.enum_tipo_token not null,
  parametros   jsonb null,
  ativo        boolean default true,
  constraint tokens_pkey primary key (id)
);

grant select, insert, update, delete on adm.tokens to sgisis;
grant select, insert, update, delete on adm.tokens to sgitec;
grant select on adm.tokens to consulta;

/******************************************************************************************
 * TABELA: audit.adm_tokens
 */
create table audit.adm_tokens (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  id             uuid not null,
  validade       date not null,
  tipo           adm.enum_tipo_token not null,
  parametros     jsonb null,
  ativo          boolean null
);

create index adm_tokens_idx1 on audit.adm_tokens (dh_audit, oper_audit, usuario_audit);
create index adm_tokens_idx2 on audit.adm_tokens (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_tokens to sgisis;
grant select on audit.adm_tokens to sgitec;
grant select on audit.adm_tokens to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.tokens for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.tokens for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.tokens for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.tokens for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.tokens for each row execute function audit.func_audit_after();


/******************************************************************************************
 * Procedure: adm.proc_gerar_grupos_permissoes_padroes
 *
 * Provisiona automaticamente os grupos de permissão padrão de uma conta ao habilitar um
 * módulo (chamada pela trigger contas_modulos_aiu). Módulo 1 (Administração) recebe um
 * grupo "Administrador" com acesso total, vinculado ao usuário "admin" (se existir) e a
 * todo usuário já administrador da conta no módulo 1. Demais módulos recebem os grupos
 * "Administrador" e "Consultas e Relatórios".
 */
create or replace procedure adm.proc_gerar_grupos_permissoes_padroes(in p_conta integer, in p_modulo integer)
 language plpgsql
as $procedure$
declare
  v_grupo   varchar(100);
  v_usuario varchar(100);
  r         record;
begin
  if exists(select * from adm.contas where id = p_conta) then
    if exists(select * from adm.modulos where id = p_modulo) then

      if p_modulo = 1 then
        if exists(select * from adm.contas_modulos where conta_id = p_conta and modulo_id = p_modulo) then
          v_grupo = 'Administrador';
          if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
            insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
            values (v_grupo, p_conta, p_modulo, true, true, true);
          end if;

          v_usuario = 'admin';
          if exists(select * from adm.usuarios where login = v_usuario) then
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end if;

          for r in
            select gpu.usuario_login
            from adm.grupos_permissoes gp
            join adm.grupos_permissoes_usuarios gpu on (gp.id = gpu.grupo_permissao_id)
            where gp.descricao = 'Administrador' and gp.modulo_id = 1 and gp.conta_id = p_conta
          loop
            v_usuario = r.usuario_login;
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end loop;
        end if;
      end if;

      if p_modulo <> 1 then
        if exists(select * from adm.contas_modulos where conta_id = p_conta and modulo_id = p_modulo) then
          v_grupo = 'Administrador';
          if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
            insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
            values (v_grupo, p_conta, p_modulo, true, true, true);
          end if;

          for r in
            select gpu.usuario_login
            from adm.grupos_permissoes gp
            join adm.grupos_permissoes_usuarios gpu on (gp.id = gpu.grupo_permissao_id)
            where gp.descricao = 'Administrador' and gp.modulo_id = 1 and gp.conta_id = p_conta
          loop
            v_usuario = r.usuario_login;
            if not exists(select * from adm.grupos_permissoes_usuarios where usuario_login = v_usuario and grupo_permissao_id = (select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo)) then
              insert into adm.grupos_permissoes_usuarios (grupo_permissao_id, usuario_login)
              values ((select id from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo), v_usuario);
            end if;
          end loop;

          v_grupo = 'Consultas e Relatórios';
          if not exists(select * from adm.grupos_permissoes where conta_id = p_conta and descricao = v_grupo and modulo_id = p_modulo) then
            insert into adm.grupos_permissoes (descricao, conta_id, modulo_id, todos_menus, todos_relatorios, todas_consultas)
            values (v_grupo, p_conta, p_modulo, false, true, true);
          end if;
        end if;
      end if;

    end if;
  end if;
end;
$procedure$;


/******************************************************************************************
 * TABELA: adm.contas
 *
 * Tenant de topo do sistema (substitui adm.ugs do Sigein). Uma "conta" é uma empresa ou
 * pessoa física cadastrada via autoatendimento — `tipo_pessoa` define qual documento é
 * exigido (`cnpj` para jurídica, `cpf` para física; `contas_tipo_pessoa_chk` garante que
 * só o documento correspondente esteja preenchido). `nome` guarda a razão social (PJ) ou
 * o nome completo (PF); `nome_fantasia` é opcional para ambos. `id` é identity (sequence
 * real), não smallint manual, pois o crescimento via autoatendimento não é previsível
 * como o número de UGs.
 */
create table adm.contas (
  created_by       varchar(50) default current_user not null,
  created_at       timestamp(0) default current_timestamp not null,
  updated_by       varchar(50) default current_user not null,
  updated_at       timestamp(0) default current_timestamp not null,
  deleted_by       varchar(50) null,
  id               integer generated by default as identity,
  tipo_pessoa      adm.enum_tipo_pessoa default 'juridica' not null,
  cnpj             varchar(14) null,
  cpf              varchar(11) null,
  nome             varchar(150) not null,
  nome_fantasia    varchar(150) null,
  email_contato    varchar(150) not null,
  telefone         varchar(20) null,
  status           adm.enum_status_conta default 'trial' not null,
  trial_expira_em  date null,
  constraint contas_pkey primary key (id),
  constraint contas_cnpj_ukey unique (cnpj),
  constraint contas_cpf_ukey unique (cpf),
  constraint contas_cnpj_chk check (adm.func_valida_cnpj(cnpj)),
  constraint contas_cpf_chk check (adm.func_valida_cpf(cpf)),
  constraint contas_tipo_pessoa_chk check (
    (tipo_pessoa = 'juridica' and cnpj is not null and cpf is null) or
    (tipo_pessoa = 'fisica' and cpf is not null and cnpj is null)
  )
);

-- fora de escopo por enquanto (não construir agora): adm.planos / adm.assinaturas
-- (catálogo de planos, cobrança), campos de endereço para faturamento.

grant select, insert, update, delete on adm.contas to sgisis;
grant select, update on adm.contas to sgitec;
grant select on adm.contas to consulta;

/******************************************************************************************
 * TABELA: audit.adm_contas
 */
create table audit.adm_contas (
  usuario_audit    varchar(50) default current_user not null,
  oper_audit       audit.enum_oper_audit default 'I' not null,
  dh_audit         timestamp(0) default current_timestamp not null,
  id               integer not null,
  tipo_pessoa      adm.enum_tipo_pessoa not null,
  cnpj             varchar(14) null,
  cpf              varchar(11) null,
  nome             varchar(150) not null,
  nome_fantasia    varchar(150) null,
  email_contato    varchar(150) not null,
  telefone         varchar(20) null,
  status           adm.enum_status_conta not null,
  trial_expira_em  date null
);

create index adm_contas_idx1 on audit.adm_contas (dh_audit, oper_audit, usuario_audit);
create index adm_contas_idx2 on audit.adm_contas (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_contas to sgisis;
grant select on audit.adm_contas to sgitec;
grant select on audit.adm_contas to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.contas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.contas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.contas for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.contas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.contas for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.modulos
 *
 * Global — módulos do sistema, curados pela equipe (INSERT/UPDATE apenas via migration,
 * por isso sgisis/sgitec recebem somente SELECT).
 */
create table adm.modulos (
  created_by   varchar(50) default current_user not null,
  created_at   timestamp(0) default current_timestamp not null,
  updated_by   varchar(50) default current_user not null,
  updated_at   timestamp(0) default current_timestamp not null,
  deleted_by   varchar(50) null,
  id           smallint not null,
  descricao    text not null,
  subdominio   text null,
  icon         text null,
  dev_port     integer null,
  constraint modulos_pkey primary key (id),
  constraint modulos_descricao_ukey unique (descricao)
);

grant select on adm.modulos to sgisis;
grant select on adm.modulos to sgitec;
grant select on adm.modulos to consulta;

/******************************************************************************************
 * TABELA: audit.adm_modulos
 */
create table audit.adm_modulos (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  id             smallint not null,
  descricao      text not null,
  subdominio     text null,
  icon           text null,
  dev_port       integer null
);

create index adm_modulos_idx1 on audit.adm_modulos (dh_audit, oper_audit, usuario_audit);
create index adm_modulos_idx2 on audit.adm_modulos (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_modulos to sgisis;
grant select on audit.adm_modulos to sgitec;
grant select on audit.adm_modulos to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.modulos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.modulos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.modulos for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.modulos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.modulos for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.menus
 */
create table adm.menus (
  created_by    varchar(50) default current_user not null,
  created_at    timestamp(0) default current_timestamp not null,
  updated_by    varchar(50) default current_user not null,
  updated_at    timestamp(0) default current_timestamp not null,
  deleted_by    varchar(50) null,
  id            serial,
  modulo_id     smallint not null,
  menu_pai_id   integer null,
  ordem         smallint null,
  descricao     text not null,
  rota          text null,
  icon          text null,
  constraint menus_pkey primary key (id),
  constraint menus_ukey unique nulls not distinct (modulo_id, menu_pai_id, descricao),
  constraint menus_modulo_id_fkey foreign key (modulo_id) references adm.modulos (id),
  constraint menus_menu_pai_id_fkey foreign key (menu_pai_id) references adm.menus (id)
);

grant select on adm.menus to sgisis;
grant select on adm.menus to sgitec;
grant select on adm.menus to consulta;

/******************************************************************************************
 * TABELA: audit.adm_menus
 */
create table audit.adm_menus (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  id             integer not null,
  modulo_id      smallint not null,
  menu_pai_id    integer null,
  ordem          smallint null,
  descricao      text not null,
  rota           text null,
  icon           text null
);

create index adm_menus_idx1 on audit.adm_menus (dh_audit, oper_audit, usuario_audit);
create index adm_menus_idx2 on audit.adm_menus (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_menus to sgisis;
grant select on audit.adm_menus to sgitec;
grant select on audit.adm_menus to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.menus for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.menus for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.menus for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.menus for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.menus for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.contas_modulos
 *
 * Substitui adm.ugs_modulos. Chave composta (conta_id, modulo_id) é o switch de
 * habilitação do módulo para a conta — ao inserir/atualizar, a trigger
 * contas_modulos_aiu provisiona os grupos de permissão padrão automaticamente.
 */
create table adm.contas_modulos (
  created_by  varchar(50) default current_user not null,
  created_at  timestamp(0) default current_timestamp not null,
  updated_by  varchar(50) default current_user not null,
  updated_at  timestamp(0) default current_timestamp not null,
  deleted_by  varchar(50) null,
  conta_id    integer not null,
  modulo_id   smallint not null,
  constraint contas_modulos_pkey primary key (conta_id, modulo_id),
  constraint contas_modulos_conta_id_fkey foreign key (conta_id) references adm.contas (id),
  constraint contas_modulos_modulo_id_fkey foreign key (modulo_id) references adm.modulos (id)
);

grant select, insert, update, delete on adm.contas_modulos to sgisis;
grant select on adm.contas_modulos to sgitec;
grant select on adm.contas_modulos to consulta;

/******************************************************************************************
 * TABELA: audit.adm_contas_modulos
 */
create table audit.adm_contas_modulos (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  conta_id       integer not null,
  modulo_id      smallint not null
);

create index adm_contas_modulos_idx1 on audit.adm_contas_modulos (dh_audit, oper_audit, usuario_audit);
create index adm_contas_modulos_idx2 on audit.adm_contas_modulos (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_contas_modulos to sgisis;
grant select on audit.adm_contas_modulos to sgitec;
grant select on audit.adm_contas_modulos to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.contas_modulos for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.contas_modulos for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.contas_modulos for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.contas_modulos for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.contas_modulos for each row execute function audit.func_audit_after();

/******************************************************************************************
 * Function: adm.trg_contas_modulos_aiu
 */
create or replace function adm.trg_contas_modulos_aiu()
 returns trigger
 language plpgsql
as $function$
begin
  call adm.proc_gerar_grupos_permissoes_padroes(new.conta_id, new.modulo_id);
  return new;
end;
$function$;

create trigger contas_modulos_aiu after insert or update on adm.contas_modulos
  for each row execute function adm.trg_contas_modulos_aiu();


/******************************************************************************************
 * TABELA: adm.consultas
 */
create table adm.consultas (
  created_by     varchar(50) default current_user not null,
  created_at     timestamp(0) default current_timestamp not null,
  updated_by     varchar(50) default current_user not null,
  updated_at     timestamp(0) default current_timestamp not null,
  deleted_by     varchar(50) null,
  id             serial,
  modulo_id      smallint not null,
  titulo         varchar(200) not null,
  is_padrao      boolean default false not null,
  descricao      text null,
  sql_consulta   text not null,
  visivel        boolean default true not null,
  constraint consultas_pkey primary key (id),
  constraint consultas_ukey unique (modulo_id, titulo),
  constraint consultas_modulo_id_fkey foreign key (modulo_id) references adm.modulos (id)
);

grant select, insert, update, delete on adm.consultas to sgisis;
grant select, insert, update, delete on adm.consultas to sgitec;
grant select on adm.consultas to consulta;

/******************************************************************************************
 * TABELA: audit.adm_consultas
 */
create table audit.adm_consultas (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  id             integer not null,
  modulo_id      smallint not null,
  titulo         varchar(200) not null,
  is_padrao      boolean not null,
  descricao      text null,
  sql_consulta   text not null,
  visivel        boolean not null
);

create index adm_consultas_idx1 on audit.adm_consultas (dh_audit, oper_audit, usuario_audit);
create index adm_consultas_idx2 on audit.adm_consultas (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_consultas to sgisis;
grant select on audit.adm_consultas to sgitec;
grant select on audit.adm_consultas to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.consultas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.consultas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.consultas for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.consultas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.consultas for each row execute function audit.func_audit_after();

/******************************************************************************************
 * Function: adm.trg_consultas_biu
 *
 * Bloqueia alteração de id e propaga exclusão lógica para adm.consultas_parametros.
 */
create or replace function adm.trg_consultas_biu()
 returns trigger
 language plpgsql
as $function$
begin
  if tg_op = 'UPDATE' then
    if new.id <> old.id then
      raise exception 'Não é permitido alterar o id';
    end if;

    if old.deleted_by is null and new.deleted_by is not null then
      update adm.consultas_parametros
         set deleted_by = new.deleted_by
       where consulta_id = new.id
         and deleted_by is null;
    end if;
  end if;

  return new;
end;
$function$;

create trigger consultas_bi before insert on adm.consultas for each row execute function adm.trg_consultas_biu();
create trigger consultas_bu before update on adm.consultas for each row execute function adm.trg_consultas_biu();


/******************************************************************************************
 * TABELA: adm.consultas_parametros
 */
create table adm.consultas_parametros (
  created_by     varchar(50) default current_user not null,
  created_at     timestamp(0) default current_timestamp not null,
  updated_by     varchar(50) default current_user not null,
  updated_at     timestamp(0) default current_timestamp not null,
  deleted_by     varchar(50) null,
  id             serial,
  consulta_id    integer not null,
  ordem          smallint not null,
  variavel       varchar(50) not null,
  nome           varchar(100) not null,
  tipo_campo     adm.enum_tipo_campo not null,
  tamanho        smallint null,
  valor_padrao   text null,
  sql_lista      text null,
  json_lista     jsonb null,
  obrigatorio    boolean default false not null,
  constraint consultas_parametros_pkey primary key (id),
  constraint consultas_parametros_nome_ukey unique (consulta_id, nome),
  constraint consultas_parametros_ordem_ukey unique (consulta_id, ordem),
  constraint consultas_parametros_var_ukey unique (consulta_id, variavel),
  constraint consultas_parametros_consulta_id_fkey foreign key (consulta_id) references adm.consultas (id) on delete cascade
);

grant select, insert, update, delete on adm.consultas_parametros to sgisis;
grant select, insert, update, delete on adm.consultas_parametros to sgitec;
grant select on adm.consultas_parametros to consulta;

/******************************************************************************************
 * TABELA: audit.adm_consultas_parametros
 */
create table audit.adm_consultas_parametros (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  id             integer not null,
  consulta_id    integer not null,
  ordem          smallint not null,
  variavel       varchar(50) not null,
  nome           varchar(100) not null,
  tipo_campo     adm.enum_tipo_campo not null,
  tamanho        smallint null,
  valor_padrao   text null,
  sql_lista      text null,
  json_lista     jsonb null,
  obrigatorio    boolean not null
);

create index adm_consultas_parametros_idx1 on audit.adm_consultas_parametros (dh_audit, oper_audit, usuario_audit);
create index adm_consultas_parametros_idx2 on audit.adm_consultas_parametros (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_consultas_parametros to sgisis;
grant select on audit.adm_consultas_parametros to sgitec;
grant select on audit.adm_consultas_parametros to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.consultas_parametros for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.consultas_parametros for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.consultas_parametros for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.consultas_parametros for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.consultas_parametros for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.relatorios
 */
create table adm.relatorios (
  created_by   varchar(50) default current_user not null,
  created_at   timestamp(0) default current_timestamp not null,
  updated_by   varchar(50) default current_user not null,
  updated_at   timestamp(0) default current_timestamp not null,
  deleted_by   varchar(50) null,
  id           serial,
  modulo_id    smallint not null,
  titulo       varchar(200) not null,
  is_padrao    boolean default false not null,
  descricao    text null,
  arquivo      text null,
  visivel      boolean default true not null,
  constraint relatorios_pkey primary key (id),
  constraint relatorios_ukey unique (modulo_id, titulo),
  constraint relatorios_modulo_id_fkey foreign key (modulo_id) references adm.modulos (id)
);

grant select, insert, update, delete on adm.relatorios to sgisis;
grant select, insert, update, delete on adm.relatorios to sgitec;
grant select on adm.relatorios to consulta;

/******************************************************************************************
 * TABELA: audit.adm_relatorios
 */
create table audit.adm_relatorios (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  id             integer not null,
  modulo_id      smallint not null,
  titulo         varchar(200) not null,
  is_padrao      boolean not null,
  descricao      text null,
  arquivo        text null,
  visivel        boolean not null
);

create index adm_relatorios_idx1 on audit.adm_relatorios (dh_audit, oper_audit, usuario_audit);
create index adm_relatorios_idx2 on audit.adm_relatorios (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_relatorios to sgisis;
grant select on audit.adm_relatorios to sgitec;
grant select on audit.adm_relatorios to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.relatorios for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.relatorios for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.relatorios for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.relatorios for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.relatorios for each row execute function audit.func_audit_after();

/******************************************************************************************
 * Criação das triggers de negócio
 *
 * Function: adm.trg_relatorios_biu — bloqueia alteração de id e propaga exclusão lógica
 * para adm.relatorios_parametros.
 */
create or replace function adm.trg_relatorios_biu()
 returns trigger
 language plpgsql
as $function$
begin
  if tg_op = 'UPDATE' then
    if new.id <> old.id then
      raise exception 'Não é permitido alterar o id';
    end if;

    if old.deleted_by is null and new.deleted_by is not null then
      update adm.relatorios_parametros
         set deleted_by = new.deleted_by
       where relatorio_id = new.id
         and deleted_by is null;
    end if;
  end if;

  return new;
end;
$function$;

create trigger relatorios_bi before insert on adm.relatorios for each row execute function adm.trg_relatorios_biu();
create trigger relatorios_bu before update on adm.relatorios for each row execute function adm.trg_relatorios_biu();


/******************************************************************************************
 * TABELA: adm.relatorios_parametros
 */
create table adm.relatorios_parametros (
  created_by     varchar(50) default current_user not null,
  created_at     timestamp(0) default current_timestamp not null,
  updated_by     varchar(50) default current_user not null,
  updated_at     timestamp(0) default current_timestamp not null,
  deleted_by     varchar(50) null,
  id             serial,
  relatorio_id   integer not null,
  ordem          smallint not null,
  variavel       varchar(50) not null,
  nome           varchar(100) not null,
  tipo_campo     adm.enum_tipo_campo not null,
  tamanho        smallint null,
  valor_padrao   text null,
  sql_lista      text null,
  json_lista     jsonb null,
  obrigatorio    boolean default false not null,
  constraint relatorios_parametros_pkey primary key (id),
  constraint relatorios_parametros_nome_ukey unique (relatorio_id, nome),
  constraint relatorios_parametros_ordem_ukey unique (relatorio_id, ordem),
  constraint relatorios_parametros_var_ukey unique (relatorio_id, variavel),
  constraint relatorios_parametros_relatorio_id_fkey foreign key (relatorio_id) references adm.relatorios (id) on delete cascade
);

grant select, insert, update, delete on adm.relatorios_parametros to sgisis;
grant select, insert, update, delete on adm.relatorios_parametros to sgitec;
grant select on adm.relatorios_parametros to consulta;

/******************************************************************************************
 * TABELA: audit.adm_relatorios_parametros
 */
create table audit.adm_relatorios_parametros (
  usuario_audit  varchar(50) default current_user not null,
  oper_audit     audit.enum_oper_audit default 'I' not null,
  dh_audit       timestamp(0) default current_timestamp not null,
  id             integer not null,
  relatorio_id   integer not null,
  ordem          smallint not null,
  variavel       varchar(50) not null,
  nome           varchar(100) not null,
  tipo_campo     adm.enum_tipo_campo not null,
  tamanho        smallint null,
  valor_padrao   text null,
  sql_lista      text null,
  json_lista     jsonb null,
  obrigatorio    boolean not null
);

create index adm_relatorios_parametros_idx1 on audit.adm_relatorios_parametros (dh_audit, oper_audit, usuario_audit);
create index adm_relatorios_parametros_idx2 on audit.adm_relatorios_parametros (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_relatorios_parametros to sgisis;
grant select on audit.adm_relatorios_parametros to sgitec;
grant select on audit.adm_relatorios_parametros to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.relatorios_parametros for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.relatorios_parametros for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.relatorios_parametros for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.relatorios_parametros for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.relatorios_parametros for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.grupos_permissoes
 *
 * Sempre escopado a exatamente um par (conta_id, modulo_id) — a FK composta garante que
 * um grupo de permissão só exista para um módulo que a conta realmente habilitou.
 */
create table adm.grupos_permissoes (
  created_by         varchar(50) default current_user not null,
  created_at         timestamp(0) default current_timestamp not null,
  updated_by         varchar(50) default current_user not null,
  updated_at         timestamp(0) default current_timestamp not null,
  deleted_by         varchar(50) null,
  id                 serial,
  descricao          text not null,
  conta_id           integer not null,
  modulo_id          smallint not null,
  todos_menus        boolean default false null,
  todos_relatorios   boolean default false null,
  todas_consultas    boolean default false null,
  constraint grupos_permissoes_pkey primary key (id),
  constraint grupos_permissoes_descricao_ukey unique (descricao, conta_id, modulo_id),
  constraint grupos_permissoes_conta_id_fkey foreign key (conta_id) references adm.contas (id) on delete cascade,
  constraint grupos_permissoes_modulo_id_fkey foreign key (modulo_id) references adm.modulos (id) on delete cascade,
  constraint grupos_permissoes_conta_id_modulo_id_fkey foreign key (conta_id, modulo_id) references adm.contas_modulos (conta_id, modulo_id) on delete cascade
);

grant select, insert, update, delete on adm.grupos_permissoes to sgisis;
grant select, insert, update, delete on adm.grupos_permissoes to sgitec;
grant select on adm.grupos_permissoes to consulta;

/******************************************************************************************
 * TABELA: audit.adm_grupos_permissoes
 */
create table audit.adm_grupos_permissoes (
  usuario_audit      varchar(50) default current_user not null,
  oper_audit         audit.enum_oper_audit default 'I' not null,
  dh_audit           timestamp(0) default current_timestamp not null,
  id                 integer not null,
  descricao          text not null,
  conta_id           integer not null,
  modulo_id          smallint not null,
  todos_menus        boolean null,
  todos_relatorios   boolean null,
  todas_consultas    boolean null
);

create index adm_grupos_permissoes_idx1 on audit.adm_grupos_permissoes (dh_audit, oper_audit, usuario_audit);
create index adm_grupos_permissoes_idx2 on audit.adm_grupos_permissoes (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_grupos_permissoes to sgisis;
grant select on audit.adm_grupos_permissoes to sgitec;
grant select on audit.adm_grupos_permissoes to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.grupos_permissoes for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.grupos_permissoes for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.grupos_permissoes for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.grupos_permissoes for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.grupos_permissoes for each row execute function audit.func_audit_after();

/******************************************************************************************
 * Function: adm.trg_grupos_permissoes_bu
 *
 * Impede excluir grupo com usuários vinculados e propaga exclusão lógica para as
 * tabelas de junção (consultas/relatórios/menus do grupo).
 */
create or replace function adm.trg_grupos_permissoes_bu()
 returns trigger
 language plpgsql
as $function$
begin
  if new.deleted_by is not null then
    if exists(select * from adm.grupos_permissoes_usuarios where grupo_permissao_id = new.id) then
      raise exception 'Não é permitido excluir grupos de permissões com usuários vinculados.';
    end if;
    update adm.grupos_permissoes_consultas set deleted_by = new.deleted_by where grupo_permissao_id = new.id;
    update adm.grupos_permissoes_relatorios set deleted_by = new.deleted_by where grupo_permissao_id = new.id;
    update adm.grupos_permissoes_menus set deleted_by = new.deleted_by where grupo_permissao_id = new.id;
  end if;
  return new;
end;
$function$;

create trigger grupos_permissoes_bu before update on adm.grupos_permissoes for each row execute function adm.trg_grupos_permissoes_bu();


/******************************************************************************************
 * TABELA: adm.grupos_permissoes_usuarios
 */
create table adm.grupos_permissoes_usuarios (
  created_by          varchar(50) default current_user not null,
  created_at          timestamp(0) default current_timestamp not null,
  updated_by          varchar(50) default current_user not null,
  updated_at          timestamp(0) default current_timestamp not null,
  deleted_by          varchar(50) null,
  grupo_permissao_id  integer not null,
  usuario_login       varchar(50) not null,
  constraint grupos_permissoes_usuarios_pkey primary key (grupo_permissao_id, usuario_login),
  constraint grupos_permissoes_usuarios_grupo_permissao_id_fkey foreign key (grupo_permissao_id) references adm.grupos_permissoes (id) on delete cascade,
  constraint grupos_permissoes_usuarios_usuario_login_fkey foreign key (usuario_login) references adm.usuarios (login) on delete cascade
);

grant select, insert, update, delete on adm.grupos_permissoes_usuarios to sgisis;
grant select, insert, update, delete on adm.grupos_permissoes_usuarios to sgitec;
grant select on adm.grupos_permissoes_usuarios to consulta;

/******************************************************************************************
 * TABELA: audit.adm_grupos_permissoes_usuarios
 */
create table audit.adm_grupos_permissoes_usuarios (
  usuario_audit       varchar(50) default current_user not null,
  oper_audit          audit.enum_oper_audit default 'I' not null,
  dh_audit            timestamp(0) default current_timestamp not null,
  grupo_permissao_id  integer not null,
  usuario_login       varchar(50) not null
);

create index adm_grupos_permissoes_usuarios_idx1 on audit.adm_grupos_permissoes_usuarios (dh_audit, oper_audit, usuario_audit);
create index adm_grupos_permissoes_usuarios_idx2 on audit.adm_grupos_permissoes_usuarios (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_grupos_permissoes_usuarios to sgisis;
grant select on audit.adm_grupos_permissoes_usuarios to sgitec;
grant select on audit.adm_grupos_permissoes_usuarios to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.grupos_permissoes_usuarios for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.grupos_permissoes_usuarios for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.grupos_permissoes_usuarios for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.grupos_permissoes_usuarios for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.grupos_permissoes_usuarios for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.grupos_permissoes_menus
 */
create table adm.grupos_permissoes_menus (
  created_by          varchar(50) default current_user not null,
  created_at          timestamp(0) default current_timestamp not null,
  updated_by          varchar(50) default current_user not null,
  updated_at          timestamp(0) default current_timestamp not null,
  deleted_by          varchar(50) null,
  grupo_permissao_id  integer not null,
  menu_id             integer not null,
  constraint grupos_permissoes_menus_pkey primary key (grupo_permissao_id, menu_id),
  constraint grupos_permissoes_menus_grupo_permissao_id_fkey foreign key (grupo_permissao_id) references adm.grupos_permissoes (id) on delete cascade,
  constraint grupos_permissoes_menus_menu_id_fkey foreign key (menu_id) references adm.menus (id) on delete cascade
);

grant select, insert, update, delete on adm.grupos_permissoes_menus to sgisis;
grant select, insert, update, delete on adm.grupos_permissoes_menus to sgitec;
grant select on adm.grupos_permissoes_menus to consulta;

/******************************************************************************************
 * TABELA: audit.adm_grupos_permissoes_menus
 */
create table audit.adm_grupos_permissoes_menus (
  usuario_audit       varchar(50) default current_user not null,
  oper_audit          audit.enum_oper_audit default 'I' not null,
  dh_audit            timestamp(0) default current_timestamp not null,
  grupo_permissao_id  integer not null,
  menu_id             integer not null
);

create index adm_grupos_permissoes_menus_idx1 on audit.adm_grupos_permissoes_menus (dh_audit, oper_audit, usuario_audit);
create index adm_grupos_permissoes_menus_idx2 on audit.adm_grupos_permissoes_menus (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_grupos_permissoes_menus to sgisis;
grant select on audit.adm_grupos_permissoes_menus to sgitec;
grant select on audit.adm_grupos_permissoes_menus to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.grupos_permissoes_menus for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.grupos_permissoes_menus for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.grupos_permissoes_menus for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.grupos_permissoes_menus for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.grupos_permissoes_menus for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.grupos_permissoes_relatorios
 */
create table adm.grupos_permissoes_relatorios (
  created_by          varchar(50) default current_user not null,
  created_at          timestamp(0) default current_timestamp not null,
  updated_by          varchar(50) default current_user not null,
  updated_at          timestamp(0) default current_timestamp not null,
  deleted_by          varchar(50) null,
  grupo_permissao_id  integer not null,
  relatorio_id        integer not null,
  constraint grupos_permissoes_relatorios_pkey primary key (grupo_permissao_id, relatorio_id),
  constraint grupos_permissoes_relatorios_grupo_permissao_id_fkey foreign key (grupo_permissao_id) references adm.grupos_permissoes (id) on delete cascade,
  constraint grupos_permissoes_relatorios_relatorio_id_fkey foreign key (relatorio_id) references adm.relatorios (id) on delete cascade
);

grant select, insert, update, delete on adm.grupos_permissoes_relatorios to sgisis;
grant select, insert, update, delete on adm.grupos_permissoes_relatorios to sgitec;
grant select on adm.grupos_permissoes_relatorios to consulta;

/******************************************************************************************
 * TABELA: audit.adm_grupos_permissoes_relatorios
 */
create table audit.adm_grupos_permissoes_relatorios (
  usuario_audit       varchar(50) default current_user not null,
  oper_audit          audit.enum_oper_audit default 'I' not null,
  dh_audit            timestamp(0) default current_timestamp not null,
  grupo_permissao_id  integer not null,
  relatorio_id        integer not null
);

create index adm_grupos_permissoes_relatorios_idx1 on audit.adm_grupos_permissoes_relatorios (dh_audit, oper_audit, usuario_audit);
create index adm_grupos_permissoes_relatorios_idx2 on audit.adm_grupos_permissoes_relatorios (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_grupos_permissoes_relatorios to sgisis;
grant select on audit.adm_grupos_permissoes_relatorios to sgitec;
grant select on audit.adm_grupos_permissoes_relatorios to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.grupos_permissoes_relatorios for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.grupos_permissoes_relatorios for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.grupos_permissoes_relatorios for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.grupos_permissoes_relatorios for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.grupos_permissoes_relatorios for each row execute function audit.func_audit_after();


/******************************************************************************************
 * TABELA: adm.grupos_permissoes_consultas
 */
create table adm.grupos_permissoes_consultas (
  created_by          varchar(50) default current_user not null,
  created_at          timestamp(0) default current_timestamp not null,
  updated_by          varchar(50) default current_user not null,
  updated_at          timestamp(0) default current_timestamp not null,
  deleted_by          varchar(50) null,
  grupo_permissao_id  integer not null,
  consulta_id         integer not null,
  constraint grupos_permissoes_consultas_pkey primary key (grupo_permissao_id, consulta_id),
  constraint grupos_permissoes_consultas_grupo_permissao_id_fkey foreign key (grupo_permissao_id) references adm.grupos_permissoes (id) on delete cascade,
  constraint grupos_permissoes_consultas_consulta_id_fkey foreign key (consulta_id) references adm.consultas (id) on delete cascade
);

grant select, insert, update, delete on adm.grupos_permissoes_consultas to sgisis;
grant select, insert, update, delete on adm.grupos_permissoes_consultas to sgitec;
grant select on adm.grupos_permissoes_consultas to consulta;

/******************************************************************************************
 * TABELA: audit.adm_grupos_permissoes_consultas
 */
create table audit.adm_grupos_permissoes_consultas (
  usuario_audit       varchar(50) default current_user not null,
  oper_audit          audit.enum_oper_audit default 'I' not null,
  dh_audit            timestamp(0) default current_timestamp not null,
  grupo_permissao_id  integer not null,
  consulta_id         integer not null
);

create index adm_grupos_permissoes_consultas_idx1 on audit.adm_grupos_permissoes_consultas (dh_audit, oper_audit, usuario_audit);
create index adm_grupos_permissoes_consultas_idx2 on audit.adm_grupos_permissoes_consultas (dh_audit, usuario_audit, oper_audit);

grant select, insert on audit.adm_grupos_permissoes_consultas to sgisis;
grant select on audit.adm_grupos_permissoes_consultas to sgitec;
grant select on audit.adm_grupos_permissoes_consultas to consulta;

/******************************************************************************************
 * Criação das triggers para audit
 */
create trigger audit_bi before insert on adm.grupos_permissoes_consultas for each row execute function audit.func_audit_before();
create trigger audit_bu before update on adm.grupos_permissoes_consultas for each row execute function audit.func_audit_before();
create trigger audit_ai after insert on adm.grupos_permissoes_consultas for each row execute function audit.func_audit_after();
create trigger audit_au after update on adm.grupos_permissoes_consultas for each row execute function audit.func_audit_after();
create trigger audit_ad after delete on adm.grupos_permissoes_consultas for each row execute function audit.func_audit_after();


/******************************************************************************************
 * VIEWS de adm
 */
create or replace view adm.view_contas_modulos as
 select cm.conta_id,
    c.nome,
    cm.modulo_id,
    m.descricao,
    m.subdominio,
    m.icon,
    m.dev_port
   from adm.contas_modulos cm
     join adm.contas c on (c.id = cm.conta_id)
     join adm.modulos m on (m.id = cm.modulo_id);

grant select on adm.view_contas_modulos to sgisis;
grant select on adm.view_contas_modulos to sgitec;
grant select on adm.view_contas_modulos to consulta;

create or replace view adm.view_usuarios_contas as
 select c.id,
    c.nome,
    gp.modulo_id,
    gpu.usuario_login
   from adm.contas c
     join adm.grupos_permissoes gp on (gp.conta_id = c.id)
     join adm.grupos_permissoes_usuarios gpu on (gpu.grupo_permissao_id = gp.id)
  group by c.id, c.nome, gp.modulo_id, gpu.usuario_login;

grant select on adm.view_usuarios_contas to sgisis;
grant select on adm.view_usuarios_contas to sgitec;
grant select on adm.view_usuarios_contas to consulta;

create or replace view adm.view_usuarios_consultas as
 select distinct u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id,
    c.id as consulta_id,
    c.titulo
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.consultas c on (c.modulo_id = gp.modulo_id)
  where gp.todas_consultas and c.visivel
union all
 select distinct u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id,
    c.id as consulta_id,
    c.titulo
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.grupos_permissoes_consultas gpc on (gpc.grupo_permissao_id = gp.id)
     join adm.consultas c on (c.id = gpc.consulta_id)
  where gp.todas_consultas = false and c.visivel;

grant select on adm.view_usuarios_consultas to sgisis;
grant select on adm.view_usuarios_consultas to sgitec;
grant select on adm.view_usuarios_consultas to consulta;

create or replace view adm.view_usuarios_menus as
 select distinct m.id,
    m.rota,
    u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.menus m on (m.modulo_id = gp.modulo_id)
  where gp.todos_menus = true and m.rota is not null
union all
 select distinct m.id,
    m.rota,
    u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.grupos_permissoes_menus gpm on (gpm.grupo_permissao_id = gp.id)
     join adm.menus m on (m.id = gpm.menu_id)
  where gp.todos_menus = false
union all
 select distinct m.id,
    m.rota,
    u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.menus m on (m.rota = 'relatorios/executar')
  where gp.todos_menus = false and gp.todos_relatorios
union all
 select distinct m.id,
    m.rota,
    u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.menus m on (m.rota = 'consultas/executar')
  where gp.todos_menus = false and gp.todas_consultas;

grant select on adm.view_usuarios_menus to sgisis;
grant select on adm.view_usuarios_menus to sgitec;
grant select on adm.view_usuarios_menus to consulta;

create or replace view adm.view_usuarios_modulos as
 select m.id,
    m.descricao,
    gp.conta_id,
    gpu.usuario_login,
    m.subdominio,
    m.icon,
    m.dev_port
   from adm.modulos m
     join adm.grupos_permissoes gp on (gp.modulo_id = m.id)
     join adm.grupos_permissoes_usuarios gpu on (gpu.grupo_permissao_id = gp.id)
  group by m.id, m.descricao, gp.conta_id, gpu.usuario_login;

grant select on adm.view_usuarios_modulos to sgisis;
grant select on adm.view_usuarios_modulos to sgitec;
grant select on adm.view_usuarios_modulos to consulta;

create or replace view adm.view_usuarios_relatorios as
 select distinct u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id,
    r.id as relatorio_id,
    r.titulo
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.relatorios r on (r.modulo_id = gp.modulo_id)
  where gp.todos_relatorios and r.visivel
union all
 select distinct u.login as usuario_login,
    gp.conta_id,
    gp.modulo_id,
    r.id as relatorio_id,
    r.titulo
   from adm.usuarios u
     join adm.grupos_permissoes_usuarios gpu on (gpu.usuario_login = u.login)
     join adm.grupos_permissoes gp on (gp.id = gpu.grupo_permissao_id)
     join adm.grupos_permissoes_relatorios gpr on (gpr.grupo_permissao_id = gp.id)
     join adm.relatorios r on (r.id = gpr.relatorio_id)
  where gp.todos_relatorios = false and r.visivel;

grant select on adm.view_usuarios_relatorios to sgisis;
grant select on adm.view_usuarios_relatorios to sgitec;
grant select on adm.view_usuarios_relatorios to consulta;


/******************************************************************************************
 * TABELA: audit.log_acessos
 *
 * Log de acessos da aplicação. Não é espelho de tabela de negócio — vive só em `audit`,
 * escrito diretamente pela aplicação (sem trigger de auditoria genérica).
 */
create table audit.log_acessos (
  id            bigint generated by default as identity,
  usuario_login varchar(50) default current_user not null,
  dh_acesso     timestamp(0) default current_timestamp not null,
  modulo_id     smallint not null,
  rota          text not null,
  ip            varchar(15) null,
  context       jsonb null,
  user_agent    text null,
  constraint log_acessos_pkey primary key (id)
);

create index log_acessos_idx1 on audit.log_acessos (dh_acesso, usuario_login, modulo_id, rota);
create index log_acessos_idx2 on audit.log_acessos (dh_acesso, modulo_id, rota, usuario_login);
create index log_acessos_idx3 on audit.log_acessos (modulo_id, rota, usuario_login, dh_acesso);
create index log_acessos_idx4 on audit.log_acessos (usuario_login, modulo_id, rota, dh_acesso);

grant select, insert on audit.log_acessos to sgisis;
grant select on audit.log_acessos to sgitec;
grant select on audit.log_acessos to consulta;


/******************************************************************************************
 * TABELA: adm.contas_sequencias
 * FUNÇÃO: adm.func_id_before
 *
 * Infraestrutura de geração de id sequencial por conta (trigger id_bi), pronta para uso
 * pelas tabelas de negócio do schema `patrim` quando este for portado em migrations
 * futuras (nenhuma tabela deste arquivo a utiliza ainda). Diferente da versão original do
 * Sigein (SELECT MAX(id)+1 ... WHERE ug_id = $1, sujeita a corrida sob inserts
 * concorrentes na mesma conta — aceitável para UGs manualmente provisionadas, mas não
 * para autoatendimento com múltiplas instâncias de aplicação), aqui o id é obtido via
 * UPSERT em adm.contas_sequencias, que serializa automaticamente pelo lock de linha do
 * PostgreSQL, sem scan de agregação. IDs não são reaproveitados após delete de linhas
 * (apenas incrementam) — mais coerente com o histórico em audit.*.
 */
create table adm.contas_sequencias (
  conta_id     integer not null references adm.contas,
  nome_tabela  text not null,
  proximo_id   integer default 0 not null,
  constraint contas_sequencias_pkey primary key (conta_id, nome_tabela)
);

grant select, insert, update on adm.contas_sequencias to sgisis;
grant select, insert, update on adm.contas_sequencias to sgitec;
grant select on adm.contas_sequencias to consulta;

create or replace function adm.func_id_before()
 returns trigger
 language plpgsql
as $function$
declare
  v_id         integer;
  v_has_conta  boolean;
  v_tabela     text;
begin
  if TG_OP = 'INSERT' and NEW.id is null then
    select exists (
      select 1 from information_schema.columns
      where table_schema = TG_TABLE_SCHEMA
        and table_name = TG_TABLE_NAME
        and column_name = 'conta_id'
    ) into v_has_conta;

    if v_has_conta then
      v_tabela := TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;
      insert into adm.contas_sequencias (conta_id, nome_tabela, proximo_id)
      values (NEW.conta_id, v_tabela, 1)
      on conflict (conta_id, nome_tabela)
      do update set proximo_id = adm.contas_sequencias.proximo_id + 1
      returning proximo_id into v_id;
      NEW.id := v_id;
    else
      execute format('select coalesce(max(id),0)+1 from %I.%I', TG_TABLE_SCHEMA, TG_TABLE_NAME) into v_id;
      NEW.id := v_id;
    end if;
  end if;
  return NEW;
end;
$function$;


/******************************************************************************************
 * Grants de sequences
 */
grant usage on all sequences in schema adm to sgisis;
grant usage on all sequences in schema adm to sgitec;
grant usage on all sequences in schema audit to sgisis;
grant usage on all sequences in schema audit to sgitec;


/******************************************************************************************
 * Seed: módulo 1 - Administração
 *
 * O módulo 1 (Administração) é referenciado por convenção em
 * adm.trg_usuarios_bu/adm.proc_gerar_grupos_permissoes_padroes como o módulo cujo grupo
 * "Administrador" concede acesso administrativo pleno à conta.
 */
insert into adm.modulos (id, descricao, subdominio) values (1, 'Administração', 'adm');
