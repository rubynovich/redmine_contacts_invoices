class ExpensesController < ApplicationController
  unloadable

  before_filter :find_expense_project, :only => [:create, :new]
  before_filter :find_expense, :only => [:edit, :show, :destroy, :update]  
  before_filter :bulk_find_expenses, :only => [:bulk_update, :bulk_edit, :bulk_destroy, :context_menu]
  before_filter :authorize, :except => [:index, :edit, :update, :destroy]
  before_filter :find_optional_project, :only => [:index] 

  accept_api_auth :index, :show, :create, :update, :destroy
  
  helper :attachments
  helper :contacts
  helper :invoices
  helper :custom_fields
  helper :timelog
  helper :sort
  helper :context_menus
  include ExpensesHelper
  include DealsHelper
  include SortHelper
  
  def index
    # retrieve_expenses_query

    @current_week_sum = expenses_sum_by_period("current_week")
    @last_week_sum = expenses_sum_by_period("last_week")
    @current_month_sum = expenses_sum_by_period("current_month")
    @last_month_sum = expenses_sum_by_period("last_month")
    @current_year_sum = expenses_sum_by_period("current_year")
    
    @draft_status_sum, @draft_status_count = expenses_sum_by_status(Expense::DRAFT_EXPENSE)
    @new_status_sum, @new_status_count = expenses_sum_by_status(Expense::NEW_EXPENSE)
    @billed_status_sum, @billed_status_count = expenses_sum_by_status(Expense::BILLED_EXPENSE)
    @paid_status_sum, @paid_status_count = expenses_sum_by_status(Expense::PAID_EXPENSE)
    respond_to do |format|
      format.html do
         params[:status_id] = "o" unless params.has_key?(:status_id)
         @expenses_sum = find_expenses.sum(:price)
         @expenses = find_expenses
         render( :partial => 'list', :layout => false, :locals => {:expenses => @expenses}) if request.xhr?
      end   
      format.api { @expenses = find_expenses }
      format.csv { send_data(expenses_to_csv(@expenses = find_expenses), :type => 'text/csv; header=present', :filename => 'expenses.csv') }

    end
  end

  def edit
    @current_week_sum = expenses_sum_by_period("current_week", @expense.contact_id)
    @last_week_sum = expenses_sum_by_period("last_week", @expense.contact_id)
    @current_month_sum = expenses_sum_by_period("current_month", @expense.contact_id)
    @last_month_sum = expenses_sum_by_period("last_month", @expense.contact_id)
    @current_year_sum = expenses_sum_by_period("current_year", @expense.contact_id)
    
    @draft_status_sum, @draft_status_count = expenses_sum_by_status(Expense::DRAFT_EXPENSE, @expense.contact_id)
    @new_status_sum, @new_status_count = expenses_sum_by_status(Expense::NEW_EXPENSE, @expense.contact_id)
    @billed_status_sum, @billed_status_count = expenses_sum_by_status(Expense::BILLED_EXPENSE, @expense.contact_id)
    @paid_status_sum, @paid_status_count = expenses_sum_by_status(Expense::PAID_EXPENSE, @expense.contact_id)

  end

  def show
  end

  def new
    @expense = Expense.new
    @expense.expense_date = Date.today
  end

  def create
    @expense = Expense.new(params[:expense])  
    # @invoice.contacts = [Contact.find(params[:contacts])]
    @expense.project = @project 
    @expense.author = User.current  
    if @expense.save
      attachments = Attachment.attach_files(@expense, (params[:attachments] || (params[:expense] && params[:expense][:uploads])))
      render_attachment_warning_if_needed(@expense)

      flash[:notice] = l(:notice_successful_create)
      
      respond_to do |format|
        format.html { redirect_to :action => "index", :project_id => @project }
        format.api  { render :action => 'show', :status => :created, :location => expense_url(@expense) }
      end
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@expense) }
      end
    end
    
  end
  
  def update
    (render_403; return false) unless @expense.editable_by?(User.current)
    if @expense.update_attributes(params[:expense]) 
      attachments = Attachment.attach_files(@expense, (params[:attachments] || (params[:expense] && params[:expense][:uploads])))
      render_attachment_warning_if_needed(@expense)      
      flash[:notice] = l(:notice_successful_update)  
      respond_to do |format| 
        format.html { redirect_to :action => "index", :project_id => @expense.project } 
        format.api  { head :ok }
      end  
    else           
      respond_to do |format|
        format.html { render :action => "edit"}
        format.api  { render_validation_errors(@expense) }
      end
    end
  end
  
  def destroy  
    (render_403; return false) unless @expense.destroyable_by?(User.current)
    if @expense.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:notice_unsuccessful_save)
    end
    respond_to do |format|
      format.html { redirect_to :action => "index", :project_id => @expense.project }
      format.api  { head :ok }
    end
    
  end
  
  def context_menu 
    @expense = @expenses.first if (@expenses.size == 1)
    @can = {:edit =>  @expenses.collect{|c| c.editable_by?(User.current)}.inject{|memo,d| memo && d}, 
            :delete => @expenses.collect{|c| c.destroyable_by?(User.current)}.inject{|memo,d| memo && d}
            }   
            
    @back = back_url        
    render :layout => false  
  end   
  
  def bulk_update
    unsaved_expense_ids = []
    @expenses.each do |expense|
      unless expense.update_attributes(parse_params_for_bulk_expense_attributes(params))
        # Keep unsaved issue ids to display them in flash error
        unsaved_expense_ids << expense.id
      end
    end
    set_flash_from_bulk_issue_save(@expenses, unsaved_expense_ids)
    redirect_back_or_default({:controller => 'expenses', :action => 'index', :project_id => @project})
    
  end   

  def bulk_destroy  
    @expenses.each do |expense|
      begin
        expense.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
        # nothing to do, issue was already deleted (eg. by a parent)
      end
    end
    respond_to do |format|
      format.html { redirect_back_or_default(:action => 'index', :project_id => @project) }
      format.api  { head :ok }
    end      
  end
  
  private

  def expenses_sum_by_period(peroid, contact_id=nil)
     retrieve_date_range(peroid)
     scope = Expense.scoped({}) 
     scope = scope.visible
     scope = scope.by_project(@project.id) if @project
     scope = scope.scoped(:conditions => ["#{Expense.table_name}.expense_date BETWEEN ? AND ?", @from, @to])
     scope = scope.scoped(:conditions => ["#{Expense.table_name}.contact_id = ?", contact_id]) unless contact_id.blank?
     scope.sum(:price)
  end

  def expenses_sum_by_status(status_id, contact_id=nil)
    scope = Expense.scoped({}) 
    scope = scope.visible
    scope = scope.by_project(@project.id) if @project
    scope = scope.scoped(:conditions => ["#{Expense.table_name}.status_id = ?", status_id])
    scope = scope.scoped(:conditions => ["#{Expense.table_name}.contact_id = ?", contact_id]) unless contact_id.blank?
    [scope.sum(:price), scope.count(:price)]
  end
  
  def find_expenses(pages=true)  
    retrieve_date_range(params[:period].to_s)
    scope = Expense.scoped({})   
    scope = scope.by_project(@project.id) if @project
    scope = scope.scoped(:conditions => ["#{Expense.table_name}.status_id = ?", params[:status_id]]) if (!params[:status_id].blank? && params[:status_id] != "o" && params[:status_id] != "d")
    scope = scope.scoped(:conditions => ["#{Expense.table_name}.status_id <> ?", Expense::PAID_EXPENSE]) if (params[:status_id] == "o") || (params[:status_id] == "d")
    scope = scope.scoped(:conditions => ["#{Expense.table_name}.contact_id = ?", params[:contact_id]]) if !params[:contact_id].blank?
    scope = scope.scoped(:conditions => ["#{Expense.table_name}.assigned_to_id = ?", params[:assigned_to_id]]) if !params[:assigned_to_id].blank? 
    scope = scope.scoped(:conditions => ["#{Expense.table_name}.expense_date BETWEEN ? AND ?", @from, @to]) if (@from && @to)


    sort_init 'status', 'expense_date'
    sort_update 'status' => 'status_id', 
                'expense_date' => 'expense_date', 
                'description' => "#{Expense.table_name}.description"
                
    scope = scope.visible
    scope = scope.scoped(:order => sort_clause) if sort_clause
    
    @expenses_count = scope.count

    if pages 
      @limit =  per_page_option 
      @expenses_pages = Paginator.new(self, @expenses_count, @limit, params[:page])     
      @offset = @expenses_pages.current.offset  
       
      scope = scope.scoped :limit  => @limit, :offset => @offset
      @expenses = scope
      
      fake_name = @expenses.first.price if @expenses.length > 0 #without this patch paging does not work
    end
    
    scope    
  end

  def parse_params_for_bulk_expense_attributes(params)
    attributes = (params[:expense] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    attributes[:custom_field_values].reject! {|k,v| v.blank?} if attributes[:custom_field_values]
    attributes
  end  
  
  def bulk_find_expenses
    @expenses = Expense.find_all_by_id(params[:id] || params[:ids], :include => :project)
    raise ActiveRecord::RecordNotFound if @expenses.empty?
    if @expenses.detect {|expense| !expense.visible?}
      deny_access
      return
    end
    @projects = @expenses.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_expense_project
    project_id = params[:project_id] || (params[:expense] && params[:expense][:project_id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_expense
    @expense = Expense.find(params[:id], :include => [:project, :contact])
    @project ||= @expense.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
end
