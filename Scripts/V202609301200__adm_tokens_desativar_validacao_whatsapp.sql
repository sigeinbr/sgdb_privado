/******************************************************************************************
 * adm.tokens: desativa os tokens do fluxo antigo de validação de WhatsApp (código enviado
 * pelo sistema), substituído pelo cadastro iniciado pelo cliente. Desativa em vez de
 * excluir — mesmo tratamento que a aplicação dá a token consumido.
 *
 * O valor 'validacao_whatsapp' de adm.enum_tipo_token permanece: remover valor de enum
 * exige recriar o tipo, e audit.adm_tokens ainda o referencia.
 */
update adm.tokens
   set ativo = false
 where tipo = 'validacao_whatsapp'
   and ativo is distinct from false;
