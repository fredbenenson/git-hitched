module Admin
  class DashboardController < BaseController
    def index
      @total_invites = Invite.count
      @responded_invites = Invite.where.not(responded_at: nil).count
      @total_guests = Guest.count
      @events = Event.order(:date, :start_time)
      @meal_counts = Guest.where.not(meal_choice: :tbd).group(:meal_choice).count
      @attending_invites = Invite.where(attending: true).count
      @declined_invites = Invite.where(attending: false).count
      @pending_invites = Invite.where(responded_at: nil).count
      @children_count = Guest.children.count
      @childcare_count = Guest.where(needs_childcare: true).count
      @recent_notes = Invite.where.not(notes: [ nil, "" ]).order(responded_at: :desc).limit(10)
      ceremony = Event.where("LOWER(name) LIKE ?", "%ceremony%").first
      @recent_ceremony_rsvps = if ceremony
        Rsvp.where(event: ceremony)
            .includes(guest: :invite)
            .order(updated_at: :desc)
            .limit(10)
      else
        Rsvp.none
      end
    end
  end
end
