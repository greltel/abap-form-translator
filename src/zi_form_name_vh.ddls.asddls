@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Form Names'
define view entity ZI_FORM_NAME_VH
  as select from zabap_form_trans
{
      @Search.defaultSearchElement: true
  key form as FormName
}
group by
  form
