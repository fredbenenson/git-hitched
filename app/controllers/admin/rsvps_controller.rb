module Admin
  class RsvpsController < BaseController
    before_action :set_invite

    def edit
      load_guests_and_events
      ensure_rsvps_exist
    end

    def update
      attending = params[:invite].present? && params[:invite][:attending] == "1"

      ActiveRecord::Base.transaction do
        if params[:guests].present?
          params[:guests].each do |guest_id, guest_params|
            guest = @invite.guests.find(guest_id)
            if guest_params[:_destroy] == "1"
              guest.destroy!
              next
            end
            guest.update!(guest_params.permit(:first_name, :last_name, :meal_choice, :dietary_notes, :needs_childcare, :needs_highchair, :age))
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
              child_params.permit(:first_name, :last_name, :meal_choice, :dietary_notes, :needs_childcare, :needs_highchair, :age).merge(is_child: true)
            )
          end
        end

        if params[:rsvps].present?
          params[:rsvps].each do |event_id, guests_hash|
            guests_hash.each do |guest_id, rsvp_data|
              next if rsvp_data[:attending].blank?
              guest = @invite.guests.find_by(id: guest_id)
              next unless guest
              rsvp = guest.rsvps.find_or_initialize_by(event_id: event_id)
              rsvp.update!(attending: rsvp_data[:attending])
            end
          end
        end

        if params[:reception_seating].present?
          params[:reception_seating].each do |guest_id, seating|
            guest = @invite.guests.find_by(id: guest_id)
            next unless guest&.is_child?
            guest.update!(reception_seating: seating) if Guest.reception_seatings.key?(seating)
          end
        end

        @invite.update!(
          attending: attending,
          children_attending: @invite.guests.children.exists?,
          notes: params.dig(:invite, :notes),
          responded_at: Time.current
        )
      end

      if params[:send_confirmation] == "1" && @invite.email.present?
        RsvpMailer.confirmation(@invite).deliver_later
      end

      redirect_to admin_invite_path(@invite), notice: "RSVP saved."
    rescue ActiveRecord::RecordInvalid => e
      load_guests_and_events
      ensure_rsvps_exist
      flash.now[:alert] = "There was a problem saving the RSVP: #{e.message}"
      render :edit, status: :unprocessable_entity
    end

    private

    def set_invite
      @invite = Invite.find(params[:invite_id])
    end

    def load_guests_and_events
      @adults = @invite.guests.adults.order(is_primary: :desc, first_name: :asc)
      @children = @invite.guests.children.order(:first_name)
      @guests = @adults + @children
      @events = @invite.events.order(:date, :start_time)
    end

    def ensure_rsvps_exist
      @guests.each do |guest|
        @events.each do |event|
          guest.rsvps.find_or_create_by!(event: event)
        end
      end
    end
  end
end
