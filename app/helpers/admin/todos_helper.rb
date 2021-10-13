# frozen_string_literal: true

# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
module Admin::TodosHelper
  # Returns the list of :null and :safe database column transitions.
  # Only these options should be shown on the custom todo edit form.
  def todo_edit_as_options(todo = nil)
    # Return every available todo_type if no restriction
    options = (todo.as.present? ? todo.available_as : Todo.todo_types).keys
    options.map { |k| [t("todo_types.#{k}.title"), k] }
  end

  def todo_group_options
    TodoGroup.all.map { |fg| [fg.name, fg.id] }
  end
end
