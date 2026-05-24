require "test_helper"

module Admin
  class SeatingTablesControllerTest < ActionDispatch::IntegrationTest
    def admin_auth
      { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "password") }
    end

    test "shuffle_seats permutes unlocked positions but preserves locks" do
      event = events(:welcome)
      table = event.seating_tables.first

      attendees = [ guests(:john_smith), guests(:jane_smith), guests(:mike_johnson) ]
      rsvps = attendees.map { |g| Rsvp.create!(guest: g, event: event, attending: true) }

      unlocked_a = SeatAssignment.create!(rsvp: rsvps[0], seating_table: table, seat_position: 1, locked: false)
      unlocked_b = SeatAssignment.create!(rsvp: rsvps[1], seating_table: table, seat_position: 2, locked: false)
      locked    = SeatAssignment.create!(rsvp: rsvps[2], seating_table: table, seat_position: 5, locked: true)

      post shuffle_seats_admin_seating_table_path(table),
           headers: admin_auth.merge("Accept" => "text/vnd.turbo-stream.html")

      assert_response :success

      # Locked stays at position 5.
      assert_equal 5, SeatAssignment.find_by(rsvp: rsvps[2]).seat_position
      assert SeatAssignment.find_by(rsvp: rsvps[2]).locked

      # Unlocked positions are still drawn from {1, 2} (just possibly swapped).
      shuffled_positions = [
        SeatAssignment.find_by(rsvp: rsvps[0]).seat_position,
        SeatAssignment.find_by(rsvp: rsvps[1]).seat_position
      ]
      assert_equal [ 1, 2 ].sort, shuffled_positions.sort
    end
  end
end
