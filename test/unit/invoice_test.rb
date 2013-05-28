require File.expand_path('../../test_helper', __FILE__)

class InvoiceTest < ActiveSupport::TestCase
    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/', 
                            [:contacts,
                             :contacts_projects,
                             :roles,
                             :enabled_modules])   



    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_contacts_invoices).directory + '/test/fixtures/', 
                          [:invoices,
                           :invoice_lines])
  def setup
    @project_a = Project.create(:name => "Test_a", :identifier => "testa")
    @project_b = Project.create(:name => "Test_b", :identifier => "testb")

    @contact1 = Contact.create(:first_name => "Contact_1", :projects => [@project_a])
    @invoice1 = Invoice.create(:number => "INV/20121212-1", :contact => @contact1, :project => @project_a, :status_id => Invoice::DRAFT_INVOICE, :invoice_date => Time.now)
  end
  
  def test_should_calculate_amount
    @invoice1.lines.new(:description => "Line 1", :quantity => 1, :price => 10)
    @invoice1.lines.new(:description => "Line 2", :quantity => 2, :price => 20)
    @invoice1.calculate_amount
    # assert @invoice1.save!
    assert_equal 2, @invoice1.lines.size
    assert_equal 50, @invoice1.amount.to_i
  end

  def test_should_calculate_amount_before_save
    @invoice1.lines.new(:description => "Line 1", :quantity => 1, :price => 10)
    @invoice1.lines.new(:description => "Line 2", :quantity => 2, :price => 20)
    assert @invoice1.save
    assert_equal 2, @invoice1.lines.size
    assert_equal 50, @invoice1.amount.to_i
  end

  def test_should_calculate_amount_before_destroy_line
    @invoice1.lines.create(:description => "Line 1", :quantity => 1, :price => 10)
    @invoice1.lines.create(:description => "Line 2", :quantity => 2, :price => 20)
    assert @invoice1.save
    assert_equal 50, @invoice1.amount.to_i
    @invoice1.lines.last.destroy
    @invoice1.reload
    assert_equal 10, @invoice1.amount.to_i
  end  

end
