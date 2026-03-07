@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Base View for Form Translations'
define root view entity ZI_FORM_TRANS
  as select from zabap_form_trans
{
  key form                  as FormName,
  key fieldname             as FieldName,
  key langu                 as LanguageKey,
  
      descr                 as Description,
      length                as MaxLength,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
