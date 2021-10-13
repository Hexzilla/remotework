# frozen_string_literal: true

# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class TodoController < ApplicationController
  before_action :set_current_tab, only: %i[index show]
  before_action :update_sidebar, only: :index

  # GET /todos
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

  # PUT /todos/1/complete
  #----------------------------------------------------------------------------
  def complete
    @todo = Todo.tracked_by(current_user).find(params[:id])
    @todo&.update_attributes(completed_at: Time.now, completed_by: current_user.id)

    # Make sure bucket's div gets hidden if it's the last completed task in the bucket.
    @empty_bucket = params[:bucket] if Todo.bucket_empty?(params[:bucket], current_user)

    update_sidebar unless params[:bucket].blank?
    respond_with(@todo)
  end

  # PUT /todos/1/uncomplete
  #----------------------------------------------------------------------------
  def uncomplete
    @todo = Todo.tracked_by(current_user).find(params[:id])
    @todo&.update_attributes(completed_at: nil, completed_by: nil)

    # Make sure bucket's div gets hidden if we're deleting last todo in the bucket.
    @empty_bucket = params[:bucket] if Todo.bucket_empty?(params[:bucket], current_user, @view)

    update_sidebar
    respond_with(@todo)
  end
end
