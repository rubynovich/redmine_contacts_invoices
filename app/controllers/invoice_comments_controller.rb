class InvoiceCommentsController < ApplicationController
  unloadable
  default_search_scope :invoices
  model_object Invoice
  before_filter :find_model_object
  before_filter :find_project_from_association
  before_filter :authorize

  def create
    raise Unauthorized unless @invoice.commentable?

    @comment = Comment.new
    @comment.safe_attributes = params[:comment]
    @comment.author = User.current
    if @invoice.comments << @comment
      flash[:notice] = l(:label_comment_added)
    end

    redirect_to :controller => 'invoices', :action => 'show', :id => @invoice
  end

  def destroy
    @invoice.comments.find(params[:comment_id]).destroy
    redirect_to :controller => 'invoices', :action => 'show', :id => @invoice
  end

  private

  # ApplicationController's find_model_object sets it based on the controller
  # name so it needs to be overriden and set to @invoice instead
  def find_model_object
    super
    @invoice = @object
    @comment = nil
    @invoice
  end
end
