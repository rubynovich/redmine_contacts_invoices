module RedmineContactsInvoices
  module Patches
    module ProjectsHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable

          alias_method_chain :project_settings_tabs, :invoices          
        end
      end


      module InstanceMethods
        # include ContactsHelper

        def project_settings_tabs_with_invoices
          tabs = project_settings_tabs_without_invoices

          tabs.push({ :name => 'invoices',
            :action => :manage_invoices,
            :partial => 'projects/invoices_settings',
            :label => :label_invoice_plural })
          tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}

        end
        
      end
      
    end
  end
end

unless ProjectsHelper.included_modules.include?(RedmineContactsInvoices::Patches::ProjectsHelperPatch)
  ProjectsHelper.send(:include, RedmineContactsInvoices::Patches::ProjectsHelperPatch)
end
