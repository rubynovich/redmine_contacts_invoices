require_dependency 'custom_fields_helper'

module RedmineContactsExpenses
  module Patches    

    module CustomFieldsHelperPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          alias_method_chain :custom_fields_tabs, :expenses_tab
        end
      end

      module InstanceMethods
        def custom_fields_tabs_with_expenses_tab
          tabs = custom_fields_tabs_without_expenses_tab
          tabs << {:name => 'ExpenseCustomField', :partial => 'custom_fields/index', :label => :label_expense_plural}
          return tabs
        end
      end
      
    end
    
  end
end

unless CustomFieldsHelper.included_modules.include?(RedmineContactsExpenses::Patches::CustomFieldsHelperPatch)
  CustomFieldsHelper.send(:include, RedmineContactsExpenses::Patches::CustomFieldsHelperPatch)
end
