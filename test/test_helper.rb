require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')
# require 'redgreen'  

def fixture_files_path
  "#{File.expand_path('..',__FILE__)}/fixtures/files/"
end

class RedmineContactsInvoices::TestCase  

  def uploaded_test_file(name, mime)
    ActionController::TestUploadedFile.new(ActiveSupport::TestCase.fixture_path + "/files/#{name}", mime, true)
  end
  
  def self.is_arrays_equal(a1, a2)
    (a1 - a2) - (a2 - a1) == []
  end  
       
  def self.prepare
    Role.find(1, 2, 3).each do |r| 
      r.permissions << :view_contacts
      r.permissions << :view_invoices
      r.permissions << :view_expenses      
      r.save
    end
    Role.find(1, 2).each do |r| 
      r.permissions << :edit_contacts
      r.permissions << :edit_invoices
      r.permissions << :edit_expenses      
      r.permissions << :delete_invoices
      r.permissions << :delete_expenses      
      r.save
    end

    Project.find(1, 2, 3, 4, 5).each do |project| 
      EnabledModule.create(:project => project, :name => 'contacts_module')
      EnabledModule.create(:project => project, :name => 'contacts_invoices')
      EnabledModule.create(:project => project, :name => 'contacts_expenses')      
    end
  end   
  
end
