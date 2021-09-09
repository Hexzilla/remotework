# frozen_string_literal: true

# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class SubscribesController < ApplicationController
  before_action :set_current_tab, only: %i[index show]
  before_action :update_sidebar, only: :index

  # GET /subscribes
  #----------------------------------------------------------------------------
  def index
    @view = view
    @subscribes = subscribe.find_all_grouped(current_user, @view)

    respond_with @subscribes do |format|
      format.xls { render layout: 'header' }
      format.csv { render csv: @subscribes.map(&:second).flatten }
      format.xml { render xml: @subscribes, except: [:subscribed_users] }
    end
  end

  # GET /subscribes/1
  #----------------------------------------------------------------------------
  def show
    @subscribe = subscribe.tracked_by(current_user).find(params[:id])
    respond_with(@subscribe)
  end

  # GET /subscribes/new
  #----------------------------------------------------------------------------
  def new
    @view = view
    @subscribe = subscribe.new
    @bucket = Setting.unroll(:subscribe_bucket)[1..-1] << [t(:due_specific_date, default: 'On Specific Date...'), :specific_time]
    @category = Setting.unroll(:subscribe_category)

    if params[:related]
      model, id = params[:related].split(/_(\d+)/)
      if related = model.classify.constantize.my(current_user).find_by_id(id)
        instance_variable_set("@asset", related)
      else
        respond_to_related_not_found(model) && return
      end
    end

    respond_with(@subscribe)
  end

  # GET /subscribes/1/edit                                                      AJAX
  #----------------------------------------------------------------------------
  def edit
    @view = view
    @subscribe = subscribe.tracked_by(current_user).find(params[:id])
    @bucket = Setting.unroll(:subscribe_bucket)[1..-1] << [t(:due_specific_date, default: 'On Specific Date...'), :specific_time]
    @category = Setting.unroll(:subscribe_category)
    @asset = @subscribe.asset if @subscribe.asset_id?

    @previous = subscribe.tracked_by(current_user).find_by_id(Regexp.last_match[1]) || Regexp.last_match[1].to_i if params[:previous].to_s =~ /(\d+)\z/

    respond_with(@subscribe)
  end

  # POST /subscribes
  #----------------------------------------------------------------------------
  def create
    @view = view
    @subscribe = subscribe.new(subscribe_params) # NOTE: we don't display validation messages for subscribes.

    respond_with(@subscribe) do |_format|
      if @subscribe.save
        update_sidebar if called_from_index_page?
      end
    end
  end

  # PUT /subscribes/1
  #----------------------------------------------------------------------------
  def update
    @view = view
    @subscribe = subscribe.tracked_by(current_user).find(params[:id])
    @subscribe_before_update = @subscribe.dup

    @subscribe_before_update.bucket = if @subscribe.due_at && (@subscribe.due_at < Date.today.to_time)
                                   "overdue"
                                 else
                                   @subscribe.computed_bucket
                                 end

    respond_with(@subscribe) do |_format|
      if @subscribe.update_attributes(subscribe_params)
        @subscribe.bucket = @subscribe.computed_bucket
        if called_from_index_page?
          @empty_bucket = @subscribe_before_update.bucket if subscribe.bucket_empty?(@subscribe_before_update.bucket, current_user, @view)
          update_sidebar
        end
      end
    end
  end

  # DELETE /subscribes/1
  #----------------------------------------------------------------------------
  def destroy
    @view = view
    @subscribe = subscribe.tracked_by(current_user).find(params[:id])
    @subscribe.destroy

    # Make sure bucket's div gets hidden if we're deleting last subscribe in the bucket.
    @empty_bucket = params[:bucket] if subscribe.bucket_empty?(params[:bucket], current_user, @view)

    update_sidebar if called_from_index_page?
    respond_with(@subscribe)
  end

  # PUT /subscribes/1/complete
  #----------------------------------------------------------------------------
  def complete
    @subscribe = subscribe.tracked_by(current_user).find(params[:id])
    @subscribe&.update_attributes(completed_at: Time.now, completed_by: current_user.id)

    # Make sure bucket's div gets hidden if it's the last completed subscribe in the bucket.
    @empty_bucket = params[:bucket] if subscribe.bucket_empty?(params[:bucket], current_user)

    update_sidebar unless params[:bucket].blank?
    respond_with(@subscribe)
  end

  # PUT /subscribes/1/uncomplete
  #----------------------------------------------------------------------------
  def uncomplete
    @subscribe = subscribe.tracked_by(current_user).find(params[:id])
    @subscribe&.update_attributes(completed_at: nil, completed_by: nil)

    # Make sure bucket's div gets hidden if we're deleting last subscribe in the bucket.
    @empty_bucket = params[:bucket] if subscribe.bucket_empty?(params[:bucket], current_user, @view)

    update_sidebar
    respond_with(@subscribe)
  end

  # POST /subscribes/auto_complete/query                                        AJAX
  #----------------------------------------------------------------------------
  # Handled by ApplicationController :auto_complete

  # Ajax request to filter out a list of subscribes.                            AJAX
  #----------------------------------------------------------------------------
  def filter
    @view = view

    update_session do |filters|
      if params[:checked].true?
        filters << params[:filter]
      else
        filters.delete(params[:filter])
      end
    end
  end

  protected

  def subscribe_params
    return {} unless params[:subscribe]

    params.require(:subscribe).permit(
      :user_id,
      :assigned_to,
      :completed_by,
      :name,
      :asset_id,
      :asset_type,
      :priority,
      :category,
      :bucket,
      :due_at,
      :completed_at,
      :deleted_at,
      :background_info,
      :calendar
    )
  end

  private

  # Yields array of current filters and updates the session using new values.
  #----------------------------------------------------------------------------
  def update_session
    name = "filter_by_subscribe_#{@view}"
    filters = (session[name].nil? ? [] : session[name].split(","))
    yield filters
    session[name] = filters.uniq.join(",")
  end

  # Collect data necessary to render filters sidebar.
  #----------------------------------------------------------------------------
  def update_sidebar
    @view = view
    @subscribe_total = subscribe.totals(current_user, @view)

    # Update filters session if we added, deleted, or completed a subscribe.
    if @subscribe
      update_session do |filters|
        if @empty_bucket # deleted, completed, rescheduled, or reassigned and need to hide a bucket
          filters.delete(@empty_bucket)
        elsif !@subscribe.deleted_at && !@subscribe.completed_at # created new subscribe
          filters << @subscribe.computed_bucket
        end
      end
    end

    # Create default filters if filters session is empty.
    name = "filter_by_subscribe_#{@view}"
    unless session[name]
      filters = @subscribe_total.keys.select { |key| key != :all && @subscribe_total[key] != 0 }.join(",")
      session[name] = filters unless filters.blank?
    end
  end

  # Ensure view is allowed
  #----------------------------------------------------------------------------
  def view
    view = params[:view]
    views = subscribe::ALLOWED_VIEWS
    views.include?(view) ? view : views.first
  end
end
