# frozen_string_literal: true

# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class TodoController < ApplicationController
  before_action :set_current_tab, only: %i[index show]
  before_action :update_sidebar, only: :index

  # GET /tasks
  #----------------------------------------------------------------------------
  def index
    @view = view
    @todo = Todo.find_all_grouped(current_user, @view)

    respond_with @todo do |format|
      format.xls { render layout: 'header' }
      format.csv { render csv: @todo.map(&:second).flatten }
      format.xml { render xml: @todo, except: [:subscribed_users] }
    end
  end
end
