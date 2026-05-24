require "test_helper"

module Admin
  class SeatAssignmentsControllerTest < ActionDispatch::IntegrationTest
    def admin_auth
      { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "password") }
    end

    test "toggle_lock flips the locked flag" do
      event = events(:welcome)
      rsvp = Rsvp.create!(guest: guests(:john_smith), event: event, attending: true)
      table = event.seating_tables.first
      assignment = SeatAssignment.create!(rsvp: rsvp, seating_table: table, seat_position: 1, locked: false)

      patch toggle_lock_admin_seat_assignment_path(assignment),
            headers: admin_auth.merge("Accept" => "text/vnd.turbo-stream.html")
      assert_response :success
      assert assignment.reload.locked

      patch toggle_lock_admin_seat_assignment_path(assignment),
            headers: admin_auth.merge("Accept" => "text/vnd.turbo-stream.html")
      refute assignment.reload.locked
    end
  end
end
