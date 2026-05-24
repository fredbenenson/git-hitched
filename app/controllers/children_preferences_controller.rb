class ChildrenPreferencesController < ApplicationController
  before_action :load_invite_from_token

  def show
    @children = @invite.guests.children.order(:first_name)
    @reception = Event.find_by(name: "Reception")
  end

  def update
    @children = @invite.guests.children.order(:first_name)

    ActiveRecord::Base.transaction do
      if params[:children].present?
        params[:children].each do |guest_id, attrs|
          child = @invite.guests.children.find_by(id: guest_id)
          next unless child

          updates = {
            needs_highchair: attrs[:needs_highchair] == "1"
          }
          if attrs[:reception_seating].present? && Guest.reception_seatings.key?(attrs[:reception_seating])
            updates[:reception_seating] = attrs[:reception_seating]
          end
          child.update!(updates)
        end
      end
    end

    RsvpMailer.children_preferences_notification(@invite).deliver_later

    redirect_to children_preferences_path(token: params[:token]), notice: "Thanks! Your children's preferences have been saved."
  end

  private

  def load_invite_from_token
    invite_id = Rails.application.message_verifier(:children_preferences).verify(params[:token])
    @invite = Invite.find(invite_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to rsvp_path, alert: "This link has expired. Please enter your email to manage your RSVP."
  end
end
