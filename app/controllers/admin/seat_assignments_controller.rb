module Admin
  class SeatAssignmentsController < BaseController
    def toggle_lock
      assignment = SeatAssignment.find(params[:id])
      assignment.update!(locked: !assignment.locked)

      @table = assignment.seating_table
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
