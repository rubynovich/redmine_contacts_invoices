module ApplicationHelper
  def select_invoice_tag(invoice, options={})
    field_id = options.delete(:field_id) || "invoice_id"
    field_name = options.delete(:field_name) || "invoice_id"
    display_field = !!options.delete(:display_field)
    span_id = field_id + '_selected_invoice'
    link_id = field_id + '_edit_link'
    s = ""
    s << content_tag(:span, invoice.to_s, :id => span_id)
    s << link_to(image_tag("edit.png", :alt => l(:label_edit), :style => "vertical-align:middle;"), "#", 
            :onclick => "$('##{span_id}').hide(); $(this).hide(); $('##{field_id}').show(); $('##{field_id}').val(''); return false;",
            :id => link_id,
            :style => display_field ? "display: none;" : "")
    s << text_field_tag(field_name, invoice.blank? ? '' : invoice.id, :style => display_field ? "" : "display: none;", :placeholder => l(:label_invoice_search), :id =>  field_id) 
    s << javascript_tag("observeAutocompleteField('#{field_id}', '#{escape_javascript auto_complete_invoices_path(:project_id => @project)}')")     
    s << javascript_tag("$(document).ready(function() {
                        function #{field_id}_invoice( message ) {
                            $('##{span_id}').text( message );
                            $('##{span_id}').show();
                            $('##{span_id}').scrollTop( 0 );
                            $('##{field_id}').hide();
                            $('##{link_id}').show();
                        }

                            $('##{field_id}').autocomplete({
                              source: '#{escape_javascript auto_complete_invoices_path(:project_id => @project)}',
                              select: function( event, ui ) {
                                #{field_id}_invoice( ui.item ?
                                    ui.item.label:
                                    'Nothing selected, input was ' + this.value);
                              },
                              minLength: 0
                            });
                          });")

    s.html_safe
  end        
end
