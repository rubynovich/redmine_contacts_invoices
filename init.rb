# Redmine Invoices plugin

require 'redmine'
require 'redmine_contacts_invoices'
INVOICES_VERSION_NUMBER = '2.1.1'
INVOICES_VERSION_STATUS = ''

Redmine::Plugin.register :redmine_contacts_invoices do
  name 'Redmine Invoices plugin'
  author 'RedmineCRM'
  description 'Plugin for track invoices'
  version INVOICES_VERSION_NUMBER + '-pro' + INVOICES_VERSION_STATUS

  url 'http://redminecrm.com/projects/invoices'
  author_url 'mailto:support@redminecrm.com'
  
  requires_redmine :version_or_higher => '2.1.2'
  requires_redmine_plugin :redmine_contacts, :version_or_higher => '3.2.1'
  
  settings :default => {
    :invoices_company_name => "Your company name",
    :invoices_company_representative => "Company representative name",
    :invoices_template  => "classic",
    :invoices_currecy_format  => "classic",
    :invoices_line_grouping => 0,
    :invoices_total_including_tax => 0,
    :invoices_excerpt_invoice_list => 1,
    :invoices_cross_project_contacts => true,
    :invoices_default_currency => "USD",
    :invoices_decimal_separator => ".",
    :invoices_thousands_delimiter => " ",
    :invoices_number_format => '#INV/%%YEAR%%%%MONTH%%%%DAY%%-%%ID%%',
    :invoices_company_info => "Your company address\nTax ID\nphone:\nfax:",
    :invoices_company_logo_url => "http://www.redmine.org/attachments/3458/redmine_logo_v1.png",
    :invoices_bill_info => "Your billing information (Bank, Address, IBAN, SWIFT & etc.)",
    :invoices_units  => "hours\ndays\nservice\nproducts"
  }, :partial => 'settings/contacts_invoices'
  
  
  project_module :contacts_invoices do
    permission :view_invoices, :invoices => [:index, :show, :context_menu]
    permission :edit_invoices, :invoices => [:new, :create, :edit, :update, :bulk_update],
                               :invoice_time_entries => [:new]
    permission :edit_own_invoices, :invoices => [:new, :create, :edit, :update, :delete]
    permission :delete_invoices, :invoices => [:destroy, :bulk_destroy]
    permission :delete_invoices, :invoices => [:destroy, :bulk_destroy]
    permission :comment_invoices,  :invoice_comments => :create
    permission :manage_invoices,  :projects => :settings, :contacts_settings => :save, :invoice_comments => :destroy
    permission :import_invoices, {:invoice_imports => [:new, :create]}
  end
  project_module :contacts_expenses do
    permission :view_expenses, :expenses => [:index, :show, :context_menu]
    permission :edit_expenses, :expenses => [:new, :create, :edit, :update, :bulk_update]
    permission :edit_own_expenses, :expenses => [:new, :create, :edit, :update, :delete, :bulk_update]
    permission :delete_expenses, :expenses => [:destroy, :bulk_destroy]
    permission :import_expenses, {:expense_imports => [:new, :create]}
  end
  
  menu :application_menu, :invoices, 
                          {:controller => 'invoices', :action => 'index'}, 
                          :caption => :label_invoice_plural, 
                          :param => :project_id, 
                          :if => Proc.new{User.current.allowed_to?({:controller => 'invoices', :action => 'index'}, 
                                          nil, {:global => true}) && RedmineContactsInvoices.settings[:invoices_show_in_app_menu]}
  menu :application_menu, :expenses, 
                          {:controller => 'expenses', :action => 'index'}, 
                          :caption => :label_expense_plural, 
                          :param => :project_id, 
                          :if => Proc.new{User.current.allowed_to?({:controller => 'expenses', :action => 'index'}, 
                                          nil, {:global => true}) && RedmineContactsInvoices.settings[:invoices_show_in_app_menu]}

  menu :project_menu, :expenses, {:controller => 'expenses', :action => 'index'}, :caption => :label_expense_plural, :param => :project_id

  activity_provider :expenses, :default => false, :class_name => ['Expense']
  
  menu :project_menu, :invoices, {:controller => 'invoices', :action => 'index'}, :caption => :label_invoice_plural, :param => :project_id
  
  menu :admin_menu, :invoices, {:controller => 'settings', :action => 'plugin', :id => "redmine_contacts_invoices"}, :caption => :label_invoice_plural, :param => :project_id
  
  activity_provider :invoices, :default => false, :class_name => ['Invoice'] 
  
  Redmine::Search.map do |search|
    search.register :invoices
    search.register :expenses
  end
  
end
