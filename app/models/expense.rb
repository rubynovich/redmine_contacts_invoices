class Expense < ActiveRecord::Base
  unloadable
  belongs_to :contact
  belongs_to :project
  belongs_to :author, :class_name => "User", :foreign_key => "author_id"

  scope :by_project, lambda {|project_id| {:conditions => ["#{Expense.table_name}.project_id = ?", project_id]} }                

  
  scope :visible, lambda {|*args| { :include => :project,
                                          :conditions => Project.allowed_to_condition(args.first || User.current, :view_expenses)} }                


  acts_as_event :datetime => :created_at,
                :url => Proc.new {|o| {:controller => 'expenses', :action => 'edit', :id => o}}, 	
                :type => 'icon-expense',  
                :title => Proc.new {|o| "#{l(:label_expense_created)} #{o.description} - #{o.price.to_s}" },
                :description => Proc.new {|o| [o.expense_date, o.description.to_s, o.contact.blank? ? "" : o.contact.name,  o.price.to_s].join(' ') }

  acts_as_activity_provider :type => 'expenses',               
                            :permission => :view_expenses,  
                            :timestamp => "#{table_name}.created_at",
                            :author_key => :author_id,
                            :find_options => {:include => :project}                                                        

  acts_as_searchable :columns => ["#{table_name}.description"], 
                     :date_column => "#{table_name}.created_at",
                     :include => [:project], 
                     :project_key => "#{Project.table_name}.id", 
                     :permission => :view_expenses,            
                     # sort by id so that limited eager loading doesn't break with postgresql
                     :order_column => "#{table_name}.expense_date"

  acts_as_customizable
  acts_as_attachable
  
  DRAFT_EXPENSE = 1
  NEW_EXPENSE = 2
  BILLED_EXPENSE = 3
  PAID_EXPENSE = 4

  validates_presence_of :price, :expense_date
  validates_numericality_of :price, :allow_nil => true
  
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_expenses, self.project)
  end    
  
  def editable_by?(usr, prj=nil)
    prj ||= @project || self.project    
    usr && (usr.allowed_to?(:edit_expenses, prj) || (self.author == usr && usr.allowed_to?(:edit_own_expenses, prj))) 
    # usr && usr.logged? && (usr.allowed_to?(:edit_notes, project) || (self.author == usr && usr.allowed_to?(:edit_own_notes, project)))
  end

  def destroyable_by?(usr, prj=nil)  
    prj ||= @project || self.project    
    usr && (usr.allowed_to?(:delete_expenses, prj) || (self.author == usr && usr.allowed_to?(:edit_own_expenses, prj)))
  end
  
  def status
    case self.status_id
    when DRAFT_EXPENSE
      l(:label_expense_status_draft)
    when NEW_EXPENSE
      l(:label_expense_status_new)
    when BILLED_EXPENSE
      l(:label_expense_status_billed)
    when PAID_EXPENSE
      l(:label_expense_status_paid)
    end
  end

  def price=(pr)
    super pr.to_s.gsub(/,/,'.')
  end  
  
  def is_draft
    status_id == DRAFT_EXPENSE || status_id.blank?
  end  

  def is_open
    status_id != PAID_EXPENSE
  end  

  def is_billed
    status_id == BILLED_EXPENSE
  end  

  def editable?(usr=nil) 
    usr ||= User.current
    @editable ||= self.project.visible(usr)
  end

end
