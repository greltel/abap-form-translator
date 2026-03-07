@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Value Help for Field Names'

define view entity ZI_FIELD_NAME_VH
  as select from zabap_form_trans

{
      @UI.hidden: true // Δεν χρειάζεται να το βλέπει ο χρήστης στο popup
  key form      as FormName,

      @Search.defaultSearchElement: true
  key fieldname as FieldName
}

group by form,
         fieldname
