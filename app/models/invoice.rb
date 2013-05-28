class Invoice < ActiveRecord::Base
  unloadable
  belongs_to :contact
  belongs_to :project
  belongs_to :author, :class_name => "User", :foreign_key => "author_id"
  belongs_to :assigned_to, :class_name => "User", :foreign_key => "assigned_to_id"
  has_many :lines, :class_name => "InvoiceLine", :foreign_key => "invoice_id", :order => "position", :dependent => :delete_all 
  has_many :comments, :as => :commented, :dependent => :delete_all, :order => "created_on"

  scope :by_project, lambda {|project_id| where(["#{Invoice.table_name}.project_id = ?", project_id]) unless project_id.blank? }                

  
  scope :visible, lambda {|*args| { :include => :project,
                                          :conditions => Project.allowed_to_condition(args.first || User.current, :view_invoices)} }                
  scope :live_search, lambda {|search| {:conditions =>   ["(LOWER(#{Invoice.table_name}.number) LIKE ? OR 
                                                                  LOWER(#{Invoice.table_name}.subject) LIKE ? OR 
                                                                  LOWER(#{Invoice.table_name}.description) LIKE ?)", 
                                                                 "%" + search.downcase + "%",
                                                                 "%" + search.downcase + "%",
                                                                 "%" + search.downcase + "%"] }}

  acts_as_event :datetime => :created_at,
                :url => Proc.new {|o| {:controller => 'invoices', :action => 'show', :id => o}}, 	
                :type => 'icon-invoice',  
                :title => Proc.new {|o| "#{l(:label_invoice_created)} ##{o.number} (#{o.status}): #{o.currency + ' ' if o.currency}#{o.amount}" },
                :description => Proc.new {|o| [o.number, o.contact ? o.contact.name : '', o.currency.to_s + " " + o.amount.to_s, o.description].join(' ') }

  acts_as_activity_provider :type => 'invoices',               
                            :permission => :view_invoices,  
                            :timestamp => "#{table_name}.created_at",
                            :author_key => :author_id,
                            :find_options => {:include => :project}                                                        

  acts_as_searchable :columns => ["#{table_name}.number"],  
                     :date_column => "#{table_name}.created_at",
                     :include => [:project], 
                     :project_key => "#{Project.table_name}.id", 
                     :permission => :view_invoices,            
                     # sort by id so that limited eager loading doesn't break with postgresql
                     :order_column => "#{table_name}.number"

  acts_as_customizable
  acts_as_watchable
  acts_as_attachable
  
  DRAFT_INVOICE = 1
  SENT_INVOICE = 2
  PAID_INVOICE = 3

  validates_presence_of :number, :invoice_date, :project, :status_id
  validates_uniqueness_of :number
  validates_numericality_of :discount, :allow_nil => true 

  before_save :calculate_amount
  
  accepts_nested_attributes_for :lines, :allow_destroy => true
  
  def calculate_amount
    self.amount = total_with_tax? ? (sub_amount - discount_amount) : (sub_amount + tax - discount_amount)
  end

  def sub_amount
     self.lines.inject(0){|sum,l| sum + l.price * l.quantity  }.to_f
  end

  def discount_amount
    ((discount_rate/100) * ((InvoicesSettings[:invoices_discount_after_tax, self.project].to_i > 0) ? sub_amount + tax : sub_amount))
  end
  
  def discount_rate
    case discount_type
    when 0
      (discount % 100)
    when 1
      sub_amount != 0 ? ((100 / ((InvoicesSettings[:invoices_discount_after_tax, self.project].to_i > 0) ? sub_amount + tax : sub_amount)) * discount) : 0
    else
      (discount % 100)
    end    
  end  
  
  def tax
     self.lines.to_a.sum(&:tax_amount)
  end
  
  def tax_groups
    self.lines.select{|l| !l.tax.blank? && l.tax.to_f > 0}.group_by{|l| l.tax}.map{|k, v| [k, v.sum{|l| l.tax_amount.to_f}] }
  end
  
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_invoices, self.project)
  end    
  
  def editable_by?(usr, prj=nil)
    prj ||= @project || self.project    
    usr && (usr.allowed_to?(:edit_invoices, prj) || (self.author == usr && usr.allowed_to?(:edit_own_invoices, prj))) 
    # usr && usr.logged? && (usr.allowed_to?(:edit_notes, project) || (self.author == usr && usr.allowed_to?(:edit_own_notes, project)))
  end

  def destroyable_by?(usr, prj=nil)  
    prj ||= @project || self.project    
    usr && (usr.allowed_to?(:delete_invoices, prj) || (self.author == usr && usr.allowed_to?(:edit_own_invoices, prj)))
  end

  def commentable?(user=User.current)
    user.allowed_to?(:comment_invoices, project)
  end    
  
  def total_with_tax?
    @total_with_tax ||= !(InvoicesSettings[:invoices_disable_taxes, self.project].to_i > 0) && (InvoicesSettings[:invoices_total_including_tax, self.project].to_i > 0)
  end
  
  def copy_from(arg)
    invoice = arg.is_a?(Invoice) ? arg : Invoice.visible.find(arg)
    self.attributes = invoice.attributes.dup.except("id", "number", "created_at", "updated_at")
    self.lines = invoice.lines.collect{|l| InvoiceLine.new(l.attributes.dup.except("id", "created_at", "updated_at"))}
    self.custom_field_values = invoice.custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}
    self
  end

  def self.allowed_target_projects(user=User.current)
    Project.all(:conditions => Project.allowed_to_condition(user, :edit_invoices))
  end  

  STATUSES = {
    DRAFT_INVOICE => l(:label_invoice_status_draft),
    SENT_INVOICE => l(:label_invoice_status_sent),
    PAID_INVOICE => l(:label_invoice_status_paid)
  }
  
  def status
    STATUSES[status_id]
    # case self.status_id
    # when DRAFT_INVOICE
    #   l(:label_invoice_status_draft)
    # when SENT_INVOICE
    #   l(:label_invoice_status_sent)
    # when PAID_INVOICE
    #   l(:label_invoice_status_paid)
    # end
  end

  def set_status(st)
    STATUSES.respond_to?(:key) ? STATUSES.key(st) : STATUSES.index(st)
  end
  
  def is_draft
    status_id == DRAFT_INVOICE || status_id.blank?
  end  

  def is_sent
    status_id == SENT_INVOICE
  end  

  def is_paid
    status_id == PAID_INVOICE
  end  

  def editable?(usr=nil) 
    usr ||= User.current
    @editable ||= 0 < self.projects.visible(usr).count(:conditions => Project.allowed_to_condition(usr, :edit_contacts))     
  end

  def amount_to_s
    return '' if self.amount.blank?
    Money.from_float(self.amount, self.currency).format rescue helpers.number_with_delimiter(amount, :delimiter => ' ', :precision => 2)
  end

  private

  def helpers
    ActionController::Base.helpers
  end

end
