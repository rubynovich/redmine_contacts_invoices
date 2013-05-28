class ChangeInvoicesSettings < ActiveRecord::Migration
  def up
    new_settings = {}
    Setting[:plugin_redmine_contacts_invoices].map{|k, v| new_settings["invoices_#{k}".to_sym] = Setting[:plugin_redmine_contacts_invoices][k.to_sym]}
    Setting[:plugin_redmine_contacts_invoices] = new_settings
  end

  def down
  end
end
