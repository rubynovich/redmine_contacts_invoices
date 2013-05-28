require File.expand_path('../../test_helper', __FILE__)  

class InvoiceImportTest < ActiveSupport::TestCase
  fixtures :projects  

  def test_open_correct_csv
    invoice_import = InvoiceImport.new(
      :file => Rack::Test::UploadedFile.new(fixture_files_path + "invoices_correct.csv", 'text/comma-separated-values'),
      :project => Project.first,
      :quotes_type => '"'
      )
    assert_difference('Invoice.count', 1, 'Should have 1 invoice in the database') do
      assert_equal 1, invoice_import.imported_instances.count, 'Should find 1 invoice in file'
      assert invoice_import.save, 'Should save successfully'
    end
  end

  def test_open_csv_with_custom_fields
    cf1 = InvoiceCustomField.create!(:name => 'Test', :field_format => 'int')
    cf2 = InvoiceCustomField.create!(:name => 'Bar', :field_format => 'string')
    invoice_import = InvoiceImport.new(
      :file => Rack::Test::UploadedFile.new(fixture_files_path + "invoices_cf.csv", 'text/comma-separated-values'),
      :project => Project.first,
      :quotes_type => '"'
      )
    assert_difference('Invoice.count', 1, 'Should have 1 invoice in the database') do
      assert_equal 1, invoice_import.imported_instances.count, 'Should find 1 invoice in file'
      assert invoice_import.save, 'Should save successfully'
    end 
    assert_equal "Hello", Invoice.find_by_number('11').custom_field_value(cf2.id)
  end

end
