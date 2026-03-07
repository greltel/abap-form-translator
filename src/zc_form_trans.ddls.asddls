@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Projection View for Form Translations'

@Metadata.allowExtensions: true

@Search.searchable: true

define root view entity ZC_FORM_TRANS
  provider contract transactional_query
  as projection on ZI_FORM_TRANS

{
  key FormName,
  key FieldName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Language', element: 'Language' } } ]
  key LanguageKey,

      @Search.defaultSearchElement: true
      Description,

      MaxLength,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
