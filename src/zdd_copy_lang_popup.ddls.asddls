@EndUserText.label: 'Popup for Copy Language'
define abstract entity ZDD_COPY_LANG_POPUP

{
  @Consumption.valueHelpDefinition: [ { entity: { name: 'I_Language', element: 'Language' } } ]
  @EndUserText.label: 'Target Language'
  TargetLanguage : zabap_form_trans_langu;
}
