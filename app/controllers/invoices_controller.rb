class InvoicesController < ApplicationController
  unloadable

  before_filter :find_invoice_project, :only => [:create, :new]
  before_filter :find_invoice, :only => [:edit, :show, :destroy, :update]  
  before_filter :bulk_find_invoices, :only => [:bulk_update, :bulk_edit, :bulk_destroy, :context_menu]
  before_filter :authorize, :except => [:index, :edit, :update, :destroy, :auto_complete]
  before_filter :find_optional_project, :only => [:index] 
  before_filter :find_project_by_project_id, :only => :auto_complete

  accept_api_auth :index, :show, :create, :update, :destroy

  helper :attachments
  helper :contacts
  helper :deals
  helper :issues
  helper :timelog
  helper :watchers  
  helper :custom_fields
  helper :sort
  helper :context_menus
  include SortHelper
  include InvoicesHelper
  include DealsHelper
  
  def index
    # retrieve_invoices_query
    
    @current_week_sum = invoices_sum_by_period("current_week")
    @last_week_sum = invoices_sum_by_period("last_week")
    @current_month_sum = invoices_sum_by_period("current_month")
    @last_month_sum = invoices_sum_by_period("last_month")
    @current_year_sum = invoices_sum_by_period("current_year")
    
    @status_stat = {}
    
    @draft_status_sum, @draft_status_count = invoices_sum_by_status(Invoice::DRAFT_INVOICE)
    @sent_status_sum, @sent_status_count = invoices_sum_by_status(Invoice::SENT_INVOICE)
    @paid_status_sum, @paid_status_count = invoices_sum_by_status(Invoice::PAID_INVOICE)
    
    respond_to do |format|
      format.html do
         params[:status_id] = "o" unless params.has_key?(:status_id)
         @invoices = find_invoices
         request.xhr? ? render( :partial => RedmineContactsInvoices.settings[:invoices_excerpt_invoice_list] ? 'excerpt_list' : 'list', :layout => false, :locals => {:invoices => @invoices}) : last_comments 
      end   
      format.api { @invoices = find_invoices }
      format.csv { send_data(invoices_to_csv(@invoices = find_invoices), :type => 'text/csv; header=present', :filename => 'invoices.csv') }
    end
  end

  def show
    
    @current_week_sum = invoices_sum_by_period("current_week", @invoice.contact_id)
    @last_week_sum = invoices_sum_by_period("last_week", @invoice.contact_id)
    @current_month_sum = invoices_sum_by_period("current_month", @invoice.contact_id)
    @last_month_sum = invoices_sum_by_period("last_month", @invoice.contact_id)
    @current_year_sum = invoices_sum_by_period("current_year", @invoice.contact_id)
    
    @status_stat = {}
    
    @draft_status_sum, @draft_status_count = invoices_sum_by_status(Invoice::DRAFT_INVOICE, @invoice.contact_id)
    @sent_status_sum, @sent_status_count = invoices_sum_by_status(Invoice::SENT_INVOICE, @invoice.contact_id)
    @paid_status_sum, @paid_status_count = invoices_sum_by_status(Invoice::PAID_INVOICE, @invoice.contact_id)
    
    @invoice_lines = @invoice.lines || []
    @comments = @invoice.comments
    @comments.reverse! if User.current.wants_comments_in_reverse_order?
    respond_to do |format|
      format.html { }
      format.api
      format.pdf  { send_data(invoice_to_pdf(@invoice, InvoicesSettings[:invoices_template, @project]), :type => 'application/pdf', :filename => "Invoice-#{@invoice.id}.pdf", :disposition => 'inline') }
    end
  end

  def new
    @invoice = Invoice.new
    @invoice.number = generate_invoice_number
    @invoice.invoice_date = Date.today  
    @invoice.contact = Contact.find_by_id(params[:contact_id]) if params[:contact_id] 
    @invoice.assigned_to = User.current  
    @invoice.currency = @invoice.currency || InvoicesSettings[:invoices_default_currency, @project]
    @invoice.copy_from(params[:copy_from]) if params[:copy_from]
    lines_from_time_entries

    @invoice.lines.build if @invoice.lines.blank?
    
    @last_invoice_number = Invoice.last.try(:number)
  end

  def create   
    @invoice = Invoice.new(params[:invoice])  
    @invoice.project = @project 
    @invoice.author = User.current  
    if @invoice.save 
      # @invoice.reload # monkey patch for custom fields
      # @invoice.save
      attachments = Attachment.attach_files(@invoice, (params[:attachments] || (params[:invoice] && params[:invoice][:uploads])))
      render_attachment_warning_if_needed(@invoice)
      flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        format.html { redirect_to :action => "show", :id => @invoice }
        format.api  { render :action => 'show', :status => :created, :location => invoice_url(@invoice) }
      end
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@invoice) }
      end
    end
  end

  def edit
    (render_403; return false) unless @invoice.editable_by?(User.current)
    @invoice_lines = @invoice.lines || []
    respond_to do |format|
      format.html { }
      format.xml  { }
    end
  end

  def update
    (render_403; return false) unless @invoice.editable_by?(User.current)
    if @invoice.update_attributes(params[:invoice])
      attachments = Attachment.attach_files(@invoice, (params[:attachments] || (params[:invoice] && params[:invoice][:uploads])))
      render_attachment_warning_if_needed(@invoice)
      flash[:notice] = l(:notice_successful_update)  
      respond_to do |format| 
        format.html { redirect_to :action => "show", :id => @invoice } 
        format.api  { head :ok }
      end  
    else           
      respond_to do |format|
        format.html { render :action => "edit"}
        format.api  { render_validation_errors(@invoice) }
      end
    end
  end

  def destroy  
    (render_403; return false) unless @invoice.destroyable_by?(User.current)
    if @invoice.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:notice_unsuccessful_save)
    end
    respond_to do |format|
      format.html { redirect_to :action => "index", :project_id => @project }
      format.api  { head :ok }
    end
    
  end
  
  def send_mail
  end
  
  def context_menu 
    @invoice = @invoices.first if (@invoices.size == 1)
    @can = {:edit =>  @invoices.collect{|c| c.editable_by?(User.current)}.inject{|memo,d| memo && d}, 
            :delete => @invoices.collect{|c| c.destroyable_by?(User.current)}.inject{|memo,d| memo && d},
            :create => User.current.allowed_to?(:edit_invoices, @projects) || User.current.allowed_to?(:edit_own_invoices, @projects),
            :pdf => User.current.allowed_to?(:view_invoices, @projects)
            }   
    @back = back_url        
    render :layout => false  
  end   
  
  def bulk_destroy  
    @invoices.each do |invoice|
      begin
        invoice.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
        # nothing to do, issue was already deleted (eg. by a parent)
      end
    end
    respond_to do |format|
      format.html { redirect_back_or_default({:action => "index", :project_id => params[:project_id]}) }
      format.api  { head :ok }
    end      
  end

  def bulk_update
    unsaved_invoice_ids = []
    @invoices.each do |invoice|
      unless invoice.update_attributes(parse_params_for_bulk_invoice_attributes(params))
        # Keep unsaved issue ids to display them in flash error
        unsaved_invoice_ids << invoice.id
      end
    end
    set_flash_from_bulk_issue_save(@invoices, unsaved_invoice_ids)
    redirect_back_or_default({:controller => 'invoices', :action => 'index', :project_id => @project})
    
  end    

  def auto_complete
    @invoices = []
    q = (params[:q] || params[:term]).to_s.strip
    scope = Invoice.visible
    scope = scope.limit(params[:limit] || 10)
    scope = scope.where(:currency => params[:currency]) if params[:currency]
    scope = scope.where(:status_id => params[:status_id]) if params[:status_id]
    scope = scope.live_search(q) unless q.blank?
    @invoices = scope.by_project(@project).sort!{|x, y| x.number <=> y.number }

    render :text => @invoices.map{|invoice| {
                                          'id' => invoice.id,
                                          'label' => "##{invoice.number} - #{format_date(invoice.invoice_date)}: (#{invoice.amount_to_s})",
                                          'value' => invoice.id
                                          }
                                 }.to_json
  end

  private
  
  def invoices_sum_by_period(peroid, contact_id=nil)
     retrieve_date_range(peroid)
     scope = Invoice.scoped({}) 
     scope = scope.visible
     scope = scope.by_project(@project.id) if @project
     scope = scope.scoped(:conditions => ["#{Invoice.table_name}.invoice_date >= ? AND #{Invoice.table_name}.invoice_date < ?", @from, @to])
     scope = scope.scoped(:conditions => ["#{Invoice.table_name}.contact_id = ?", contact_id]) unless contact_id.blank?
     # debugger
     scope.sum(:amount, :group => :currency)
  end

  def invoices_sum_by_status(status_id, contact_id=nil)
    scope = Invoice.scoped({}) 
    scope = scope.visible
    scope = scope.by_project(@project.id) if @project
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.status_id = ?", status_id])
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.contact_id = ?", contact_id]) unless contact_id.blank?
    [scope.sum(:amount, :group => :currency), scope.count(:number)]
  end
  
  def last_comments
    @last_comments = []
  end
  
  def find_invoice_project
    project_id = params[:project_id] || (params[:invoice] && params[:invoice][:project_id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_invoices(pages=true)  
    retrieve_date_range(params[:period].to_s)
    scope = Invoice.scoped({})   
    scope = scope.by_project(@project.id) if @project
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.status_id = ?", params[:status_id]]) if (!params[:status_id].blank? && params[:status_id] != "o" && params[:status_id] != "d")
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.status_id <> ?", Invoice::PAID_INVOICE]) if (params[:status_id] == "o") || (params[:status_id] == "d")
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.contact_id = ?", params[:contact_id]]) if !params[:contact_id].blank?
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.assigned_to_id = ?", params[:assigned_to_id]]) if !params[:assigned_to_id].blank? 
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.invoice_date BETWEEN ? AND ?", @from, @to]) if (@from && @to)
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.due_date <= ? AND #{Invoice.table_name}.status_id = ?", Date.today, Invoice::SENT_INVOICE]) if (params[:status_id] == "d")
    scope = scope.scoped(:conditions => ["#{Invoice.table_name}.due_date <= ?", params[:due_date].to_date]) if (!params[:due_date].blank? && is_date?(params[:due_date]))

    sort_init 'status', 'number'
    sort_update 'invoice_date' => 'invoice_date', 
                'status' => 'status_id', 
                'due_date' => 'due_date', 
                'number' => 'number'
                
    scope = scope.visible
    scope = scope.scoped(:order => sort_clause) if sort_clause
    
    @invoices_count = scope.count

    if pages 
      @limit =  per_page_option 
      @invoices_pages = Paginator.new(self, @invoices_count,  @limit, params[:page])     
      @offset = @invoices_pages.current.offset  
       
      scope = scope.scoped :limit  => @limit, :offset => @offset
      @invoices = scope
      
      fake_name = @invoices.first.amount if @invoices.length > 0 #without this patch paging does not work
    end
    
    scope    
  end
  def lines_from_time_entries
    if params[:issues_ids] && params[:line_grouping] 
      @invoice.lines = []
      case params[:line_grouping].to_i
      when 1  
        total_time = TimeEntry.sum(:hours, :conditions => {:issue_id => params[:issues_ids]}, :group => :issue_id)
        total_time.first
        total_time.each do |k, v|
          issue = Issue.find_by_id(k.to_i)
          @invoice.lines << InvoiceLine.new(:description => issue.subject, 
                                            :units => l(:label_invoice_hours),   
                                            :quantity => total_time[k])
        end
      when 2  
        total_time = TimeEntry.sum(:hours, :conditions => {:issue_id => params[:issues_ids]}, :group => :user_id)
        total_time.first
        total_time.each do |k, v|
          scope = Issue.scoped(:include => :time_entries,  :conditions => {:id => params[:issues_ids]})
          scope = scope.scoped(:conditions => ["#{TimeEntry.table_name}.user_id = ?", k])
          issues = scope.all
          user = User.find(k)
          @invoice.lines << InvoiceLine.new(:description => user.name.humanize + 
                                              "\n" +  
                                              issues.map{|i| " - #{i.subject} (#{l_hours(i.spent_hours)})"}.join("\n"),
                                            :units => l(:label_invoice_hours),   
                                            :quantity => total_time[k],
                                            :price => default_user_rate(user, @project))
        end
      when 3  
        total_time = TimeEntry.sum(:hours, :conditions => {:issue_id => params[:issues_ids]})
        scope = Issue.scoped(:include => :time_entries, :conditions => {:id => params[:issues_ids]})
        scope = scope.scoped(:conditions => ["#{TimeEntry.table_name}.hours > 0"])
        issues = scope.all
        @invoice.lines << InvoiceLine.new(:description => issues.map{|i| " - #{i.subject} (#{l_hours(i.spent_hours)})"}.join("\n"), 
                                          :units => l(:label_invoice_hours),   
                                          :quantity => total_time)
      when 5  
        scope = TimeEntry.scoped(:include => [{:issue => :tracker}, :activity, :user], :conditions => {:issue_id => params[:issues_ids]})
        time_entries = scope.all
        time_entries.each do |time_entry|
          issue = time_entry.issue
          line_description = "#{time_entry.activity.name} - #{issue.tracker.name} ##{issue.id}: #{issue.subject} #{'- ' + time_entry.comments + ' ' unless time_entry.comments.blank?}"
          @invoice.lines << InvoiceLine.new(:description => line_description, 
                                            :units => l(:label_invoice_hours),   
                                            :quantity => time_entry.hours,
                                            :price => default_user_rate(time_entry.user, @project))
        end
      else 
        total_time = TimeEntry.sum(:hours, :conditions => {:issue_id => params[:issues_ids]}, :group => :activity_id)
        total_time.first
        total_time.each do |k, v|
          
          # scope = TimeEntry.scoped(:include => [:issue => :tracker],  :conditions => {:issue_id => params[:issues_ids]})
          # scope = scope.scoped(:conditions => ["#{TimeEntry.table_name}.activity_id = ?", k])
          # time_entries = scope.all
          # @invoice.lines << InvoiceLine.new(:description => Enumeration.find(k).name.humanize + 
          #                                     "\n" +  
          #                                     time_entries.map{|te| " - #{te.issue.tracker.name} ##{te.issue.id}: #{te.issue.subject} #{'- ' + te.comments + ' ' unless te.comments.blank?}(#{l_hours(te.hours)})"}.join("\n"), 
          #                                   :units => l(:label_invoice_hours),   
          #                                   :quantity => total_time[k])
          
          scope = Issue.scoped(:include => :time_entries,  :conditions => {:id => params[:issues_ids]})
          scope = scope.scoped(:conditions => ["#{TimeEntry.table_name}.activity_id = ?", k])
          issues = scope.all
          @invoice.lines << InvoiceLine.new(:description => Enumeration.find(k).name.humanize + 
                                              "\n" +  
                                              issues.map{|i| " - #{i.subject} (#{l_hours(i.spent_hours)})"}.join("\n"), 
                                            :units => l(:label_invoice_hours),   
                                            :quantity => total_time[k])
        end
      end 
       
    end    
  end

  # Filter for bulk issue invoices
  def bulk_find_invoices
    @invoices = Invoice.find_all_by_id(params[:id] || params[:ids], :include => :project)
    raise ActiveRecord::RecordNotFound if @invoices.empty?
    raise Unauthorized unless @invoices.all?(&:visible?)
    @projects = @invoices.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_invoice
    @invoice = Invoice.find(params[:id], :include => [:project, :contact])
    @project ||= @invoice.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def parse_params_for_bulk_invoice_attributes(params)
    attributes = (params[:invoice] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    attributes[:custom_field_values].reject! {|k,v| v.blank?} if attributes[:custom_field_values]
    attributes
  end
  
end
