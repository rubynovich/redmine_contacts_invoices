
require File.expand_path('../../test_helper', __FILE__)

class ExpenseImportsControllerTest < ActionController::TestCase  
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries

    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/', 
                            [:contacts,
                             :contacts_projects,
                             :contacts_issues,
                             :deals,
                             :notes,
                             :roles,
                             :enabled_modules,
                             :tags,
                             :taggings,
                             :contacts_queries])   

    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_contacts_invoices).directory + '/test/fixtures/', 
                          [:invoices,
                           :invoice_lines])
 
  # TODO: Test for delete tags in update action
  
  def setup
    RedmineContactsInvoices::TestCase.prepare

    @controller = ExpenseImportsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    User.current = nil  
  end

  test 'should open expense import form' do
    @request.session[:user_id] = 1
    get :new, :project_id => 1
    assert_response :success
    assert_select 'form#import_form'
  end

  test 'should successfully import from CSV' do
    @request.session[:user_id] = 1
    assert_difference('Expense.count', 1, 'Should add 1 expense the database') do
      post :create, {
        :project_id => 1,
        :expense_import => { 
          :file => Rack::Test::UploadedFile.new(fixture_files_path + "expenses_correct.csv", 'text/comma-separated-values'),
          :quotes_type => '"'          
        }
      }
      assert_redirected_to project_expenses_path(:project_id => Project.first.id)
    end
  end
end
