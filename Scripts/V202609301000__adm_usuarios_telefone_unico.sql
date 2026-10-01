/******************************************************************************************
 * adm.usuarios: normalização do telefone + unicidade (Radar de Licitações)
 *
 * A validação do WhatsApp passa a ser iniciada pelo cliente (envia "cadastro" ao número
 * do Radar) e a API localiza o usuário pelo telefone — por isso um número vincula a um
 * único usuário.
 *
 * 1. Normaliza: só dígitos, DDD + número, sem DDI; celular de 10 dígitos (3º dígito 6–9)
 *    ganha o nono dígito; vazio vira NULL. A normalização é só de formato (mesmo
 *    número), então quem estava validado continua validado — a trigger usuarios_bu zera
 *    whatsapp_verificado ao trocar o telefone, e o valor é restaurado logo depois.
 * 2. Números compartilhados entre usuários (após normalizar) são limpos em TODOS eles,
 *    sem telefone e sem validação (decisão de produto: a pessoa recadastra pelo fluxo
 *    novo no login que escolher).
 * 3. Índice único parcial usuarios_telefone_ukey — a API traduz a violação pelo nome.
 */
create temporary table tmp_usuarios_verificados on commit drop as
select login
  from adm.usuarios
 where whatsapp_verificado;

update adm.usuarios
   set telefone = nullif(regexp_replace(telefone, '\D', '', 'g'), '')
 where telefone is distinct from nullif(regexp_replace(telefone, '\D', '', 'g'), '');

update adm.usuarios
   set telefone = substr(telefone, 1, 2) || '9' || substr(telefone, 3)
 where length(telefone) = 10
   and substr(telefone, 3, 1) in ('6', '7', '8', '9');

update adm.usuarios u
   set whatsapp_verificado = true
  from tmp_usuarios_verificados t
 where t.login = u.login
   and u.telefone is not null
   and not u.whatsapp_verificado;

update adm.usuarios
   set telefone = null,
       whatsapp_verificado = false
 where telefone in (
         select telefone
           from adm.usuarios
          where telefone is not null
          group by telefone
         having count(*) > 1
       );

create unique index usuarios_telefone_ukey
    on adm.usuarios (telefone)
 where telefone is not null;
