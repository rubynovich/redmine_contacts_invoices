require_dependency 'custom_fields_helper'

module RedmineContactsInvoices
  module Patches    

    module CustomFieldsHelperPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          if Redmine::VERSION::MAJOR >= 2 && Redmine::VERSION::MINOR >= 5
            alias_method_chain :render_custom_fields_tabs, :render_invoice_tab
            alias_method_chain :custom_field_type_options, :invoice_tab_options
          else
            alias_method_chain :custom_fields_tabs, :invoice_tab
          end
        end
      end

      module InstanceMethods
        # Adds a rates tab to the user administration page

        def custom_fields_tabs_with_invoice_tab
          add_ct
          custom_fields_tabs_without_invoice_tab
        end

        def render_custom_fields_tabs_with_render_invoice_tab(types)
          add_ct
          render_custom_fields_tabs_without_render_invoice_tab(types)
        end

        def custom_field_type_options_with_invoice_tab_options
          add_ct
          custom_field_type_options_without_invoice_tab_options
        end

        private

        def add_ct
          new_tabs = []
          new_tabs << {:name => 'InvoiceCustomField', :partial => 'custom_fields/index', :label => :label_invoice_plural}
          new_tabs << {:name => 'ExpenseCustomField', :partial => 'custom_fields/index', :label => :label_expense_plural}
          new_tabs.each do |new_tab|
            unless CustomFieldsHelper::CUSTOM_FIELDS_TABS.index { |f| f[:name] == new_tab[:name] }
              CustomFieldsHelper::CUSTOM_FIELDS_TABS << new_tab
            end
          end
        end
        
        
      end
      
    end
    
  end
end

unless CustomFieldsHelper.included_modules.include?(RedmineContactsInvoices::Patches::CustomFieldsHelperPatch)
  CustomFieldsHelper.send(:include, RedmineContactsInvoices::Patches::CustomFieldsHelperPatch)
end
