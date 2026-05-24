class RsvpsController < ApplicationController
  before_action -> { require_page_enabled!(:rsvp) }

  def new
  end

  def lookup
    query = params[:query]&.strip
    if query.blank?
      flash.now[:alert] = "Please enter your email address."
      return render :new, status: :unprocessable_entity
    end

    invite = Invite.find_by_email(query)
    if invite
      redirect_to rsvp_show_path(invite_id: invite.id)
    else
      flash.now[:alert] = "We couldn't find your invitation. Please check your email and try again."
      render :new, status: :unprocessable_entity
    end
  end

  def manage
    invite_id = Rails.application.message_verifier(:rsvp_management).verify(params[:token])
    redirect_to rsvp_show_path(invite_id: invite_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to rsvp_path, alert: "This link has expired. Please enter your email to manage your RSVP."
  end

  def show
    @invite = Invite.find(params[:invite_id])
    @adults = @invite.guests.adults.order(is_primary: :desc, first_name: :asc)
    @children = @invite.guests.children.order(:first_name)
    @guests = @adults + @children
    @events = @invite.events.order(:date, :start_time)

    if params[:step] == "confirmation"
      render :show_confirmation
    elsif params[:step] == "notes"
      render :show_notes
    elsif params[:step] == "events"
      if @guests.empty?
        redirect_to rsvp_show_path(invite_id: @invite.id), alert: "Please add your guests first."
        return
      end
      ensure_rsvps_exist
      render :show_events
    else
      ensure_rsvps_exist
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to rsvp_path, alert: "Invite not found."
  end

  def update
    @invite = Invite.find(params[:invite_id])
    @events = @invite.events.order(:date, :start_time)

    if params[:step] == "notes"
      update_notes
    elsif params[:step] == "events"
      update_events
    else
      update_guests
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to rsvp_path, alert: "Invite not found."
  rescue ActiveRecord::RecordInvalid => e
    @adults = @invite.guests.reload.adults.order(is_primary: :desc, first_name: :asc)
    @children = @invite.guests.reload.children.order(:first_name)
    @guests = @adults + @children
    flash.now[:alert] = "There was a problem saving your RSVP: #{e.message}"
    ensure_rsvps_exist
    if params[:step] == "notes"
      render :show_notes, status: :unprocessable_entity
    elsif params[:step] == "events"
      render :show_events, status: :unprocessable_entity
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def update_guests
    attending = params[:invite].present? && params[:invite][:attending] == "1"

    ActiveRecord::Base.transaction do
      if params[:guests].present?
        params[:guests].each do |guest_id, guest_params|
          guest = @invite.guests.find(guest_id)
          if guest_params[:_destroy] == "1"
            guest.destroy!
            next
          end
          guest.update!(guest_params.permit(:first_name, :last_name, :meal_choice, :dietary_notes, :needs_childcare, :age))
        end
      end

      if params[:new_guests].present?
        params[:new_guests].each do |_index, guest_params|
          next if guest_params[:first_name].blank?
          @invite.guests.create!(
            guest_params.permit(:first_name, :last_name, :meal_choice, :dietary_notes)
          )
        end
      end

      if params[:new_children].present?
        params[:new_children].each do |_index, child_params|
          next if child_params[:first_name].blank?
          @invite.guests.create!(
            child_params.permit(:first_name, :last_name, :meal_choice, :dietary_notes, :needs_childcare, :age).merge(is_child: true)
          )
        end
      end

      @invite.update!(attending: attending, children_attending: @invite.guests.children.exists?)
    end

    if attending
      redirect_to rsvp_show_path(invite_id: @invite.id, step: "events")
    else
      @invite.update!(responded_at: Time.current)
      was_first_response = @invite.responded_at_previously_was.nil?
      if was_first_response
        RsvpMailer.confirmation(@invite).deliver_later
      else
        RsvpMailer.update_notification(@invite).deliver_later
      end
      RsvpMailer.admin_notification(@invite).deliver_later
      redirect_to rsvp_show_path(invite_id: @invite.id), notice: "We're sorry you can't make it! Your response has been saved."
    end
  end

  def update_events
    ActiveRecord::Base.transaction do
      if params[:rsvps].present?
        params[:rsvps].each do |event_id, guests_hash|
          guests_hash.each do |guest_id, rsvp_data|
            guest = @invite.guests.find(guest_id)
            rsvp = guest.rsvps.find_or_initialize_by(event_id: event_id)
            rsvp.update!(rsvp_data.permit(:attending))
          end
        end
      end

      @invite.update!(children_attending: @invite.guests.children.exists?)
    end

    redirect_to rsvp_show_path(invite_id: @invite.id, step: "notes")
  end

  def update_notes
    was_first_response = @invite.responded_at.nil?

    @invite.update!(notes: params.dig(:invite, :notes), responded_at: Time.current)

    if was_first_response
      RsvpMailer.confirmation(@invite).deliver_later
    else
      RsvpMailer.update_notification(@invite).deliver_later
    end
    RsvpMailer.admin_notification(@invite).deliver_later

    redirect_to rsvp_show_path(invite_id: @invite.id, step: "confirmation")
  end

  def ensure_rsvps_exist
    @guests.each do |guest|
      @events.each do |event|
        guest.rsvps.find_or_create_by!(event: event)
      end
    end
  end
end
