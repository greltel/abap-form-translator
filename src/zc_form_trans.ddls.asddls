@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Projection View for Form Translations'

@Metadata.allowExtensions: true

@Search.searchable: true

define root view entity ZC_FORM_TRANS
  provider contract transactional_query
  as projection on ZI_FORM_TRANS

{
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_FORM_NAME_VH', element: 'FormName' } } ]
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key FormName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_FIELD_NAME_VH', element: 'FieldName' },
                                            additionalBinding: [ { localElement: 'FormName',
                                                                   element: 'FormName',
                                                                   usage: #FILTER_AND_RESULT } ] } ]
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key FieldName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Language', element: 'Language' } } ]
      @ObjectModel.text.element: [ 'LanguageName' ]
  key LanguageKey,

      @UI.hidden: true
      _LanguageText.LanguageName as LanguageName,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Description,

      MaxLength,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
