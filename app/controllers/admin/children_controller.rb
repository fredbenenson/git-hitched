module Admin
  class ChildrenController < BaseController
    AGE_BRACKETS = [
      [ "Infants (under 2)",  ->(age) { age && age < 2 } ],
      [ "Toddlers (2–4)",     ->(age) { age && age.between?(2, 4) } ],
      [ "Kids (5–9)",         ->(age) { age && age.between?(5, 9) } ],
      [ "Older (10–17)",      ->(age) { age && age.between?(10, 17) } ],
      [ "Unknown age",        ->(age) { age.nil? } ]
    ].freeze

    def index
      base = Guest.children
                  .includes(invite: :guests, rsvps: :event)
                  .joins(:invite)
                  .where(invites: { linked_invite_id: nil })
                  .order("invites.name ASC, guests.age ASC NULLS LAST, guests.first_name ASC")

      @attending = base.where(invites: { attending: true }).where.not(invites: { responded_at: nil })
      @pending   = base.where(invites: { responded_at: nil })
      @declined  = base.where(invites: { attending: false })

      @total_attending  = @attending.size
      @childcare_count  = @attending.count { |g| g.needs_childcare? }
      @highchair_count  = @attending.count { |g| g.needs_highchair? }
      @bracket_counts   = AGE_BRACKETS.map { |label, test| [ label, @attending.count { |g| test.call(g.age) } ] }

      childcare_kids = @attending.select { |g| g.needs_childcare? }
      @childcare_bracket_counts = AGE_BRACKETS.map { |label, test| [ label, childcare_kids.count { |g| test.call(g.age) } ] }

      @events = Event.order(:date, :start_time)
      @per_event_counts = @events.each_with_object({}) do |event, h|
        h[event.id] = @attending.count { |g| g.rsvps.any? { |r| r.event_id == event.id && r.attending } }
      end

      reception = @events.find { |e| e.name == "Reception" }
      if reception
        attending_reception = @attending.select { |g| g.rsvps.any? { |r| r.event_id == reception.id && r.attending } }
        @reception_with_parents = attending_reception.count { |g| g.seated_with_parents? }
        @reception_kids_area    = attending_reception.count { |g| g.seated_kids_area? }
      else
        @reception_with_parents = 0
        @reception_kids_area    = 0
      end
    end
  end
end
