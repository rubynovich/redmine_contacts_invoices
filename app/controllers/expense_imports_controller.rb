class ExpenseImportsController < ImporterBaseController
  def klass
    ExpenseImport
  end

  def instance_index
    project_expenses_path(:project_id => @project.id)
  end
end
