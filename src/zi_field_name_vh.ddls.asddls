@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true

@EndUserText.label: 'Value Help for Field Names'

define view entity ZI_FIELD_NAME_VH
  as select from zabap_form_trans

{
      @UI.hidden: true
  key form      as FormName,

      @Search.defaultSearchElement: true
  key fieldname as FieldName
}

group by form,
         fieldname
