class InvoiceImportsController < ImporterBaseController
  def klass
    InvoiceImport
  end

  def instance_index
    project_invoices_path(:project_id => @project.id)
  end
end
