module Admin
  class SeatingTablesController < BaseController
    def shuffle_seats
      @table = SeatingTable.find(params[:id])

      ApplicationRecord.transaction do
        unlocked = @table.seat_assignments.where(locked: false).to_a
        free_positions = unlocked.map(&:seat_position).shuffle

        @table.seat_assignments.where(locked: false).delete_all

        rows = unlocked.zip(free_positions).map do |assignment, position|
          {
            rsvp_id: assignment.rsvp_id,
            seating_table_id: @table.id,
            seat_position: position,
            locked: false,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        SeatAssignment.insert_all!(rows) if rows.any?
      end

      @assignments = SeatAssignment
        .where(seating_table_id: @table.id)
        .includes(rsvp: { guest: :invite })
        .each_with_object({}) { |a, h| h[[ a.seating_table_id, a.seat_position ]] = a }

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: admin_event_seating_path(@table.event) }
      end
    end
  end
end
