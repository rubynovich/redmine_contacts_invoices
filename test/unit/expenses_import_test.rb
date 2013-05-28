require File.expand_path('../../test_helper', __FILE__)  

class ExpenseImportTest < ActiveSupport::TestCase
  def fixture_files_path
    "#{File.expand_path('../..',__FILE__)}/fixtures/files/"
  end

  def test_open_correct_csv
    expense_import = ExpenseImport.new(
      :file => Rack::Test::UploadedFile.new(fixture_files_path + "expenses_correct.csv", 'text/comma-separated-values'),
      :project => Project.first,
      :quotes_type => '"'
      )
    puts expense_import.errors.full_messages.join("\n") unless expense_import.valid?
    assert_difference('Expense.count', 1, 'Should have 1 expense in the database') do
      assert_equal 1, expense_import.imported_instances.count, 'Should find 1 expense in file'
      assert expense_import.save, 'Should save successfully'
    end
  end
end
