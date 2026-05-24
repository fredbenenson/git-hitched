require "test_helper"

module Admin
  class SeatingMoveControllerTest < ActionDispatch::IntegrationTest
    def admin_auth
      { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "password") }
    end

    def turbo_headers
      admin_auth.merge("Accept" => "text/vnd.turbo-stream.html")
    end

    setup do
      @event = events(:welcome)
      @table = @event.seating_tables.first
      @rsvp_a = Rsvp.create!(guest: guests(:john_smith), event: @event, attending: true)
      @rsvp_b = Rsvp.create!(guest: guests(:jane_smith), event: @event, attending: true)
    end

    test "move endpoint moves a seated rsvp to an empty seat and returns turbo stream" do
      SeatAssignment.create!(rsvp: @rsvp_a, seating_table: @table, seat_position: 1)

      post move_admin_event_seating_path(@event),
           params: { rsvp_ids: [ @rsvp_a.id ], destination: { type: "seat", table_id: @table.id, position: 2 } },
           headers: turbo_headers

      assert_response :success
      assert_match "turbo-stream", response.media_type
      assert_match "seating_table_#{@table.id}", response.body
      assert_equal 2, SeatAssignment.find_by!(rsvp: @rsvp_a).seat_position
    end

    test "move endpoint refuses moving onto a locked seat" do
      SeatAssignment.create!(rsvp: @rsvp_a, seating_table: @table, seat_position: 1, locked: true)

      post move_admin_event_seating_path(@event),
           params: { rsvp_ids: [ @rsvp_b.id ], destination: { type: "seat", table_id: @table.id, position: 1 } },
           headers: turbo_headers

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_equal "dest_locked", body["error"]
      assert_equal @rsvp_a.id, SeatAssignment.find_by(seating_table: @table, seat_position: 1).rsvp_id
    end

    test "move endpoint updates the unseated rail when a guest leaves the rail" do
      post move_admin_event_seating_path(@event),
           params: { rsvp_ids: [ @rsvp_a.id ], destination: { type: "seat", table_id: @table.id, position: 1 } },
           headers: turbo_headers

      assert_response :success
      assert_match "seating_unseated_rail", response.body
    end

    test "move endpoint stores an undo snapshot in the session" do
      SeatAssignment.create!(rsvp: @rsvp_a, seating_table: @table, seat_position: 1)

      post move_admin_event_seating_path(@event),
           params: { rsvp_ids: [ @rsvp_a.id ], destination: { type: "seat", table_id: @table.id, position: 2 } },
           headers: turbo_headers

      assert_response :success
      undo = session[:seating_undo]
      assert undo.present?, "expected undo snapshot in session"
      snap = undo["snapshot"] || undo[:snapshot]
      assert_equal @rsvp_a.id, snap.first["rsvp_id"]
      assert_equal 1, snap.first["seat_position"]
    end

    test "undo restores the prior state" do
      SeatAssignment.create!(rsvp: @rsvp_a, seating_table: @table, seat_position: 1)

      post move_admin_event_seating_path(@event),
           params: { rsvp_ids: [ @rsvp_a.id ], destination: { type: "seat", table_id: @table.id, position: 2 } },
           headers: turbo_headers
      assert_equal 2, SeatAssignment.find_by!(rsvp: @rsvp_a).seat_position

      post undo_admin_event_seating_path(@event), headers: turbo_headers

      assert_response :success
      assert_equal 1, SeatAssignment.find_by!(rsvp: @rsvp_a).seat_position
      assert_nil session[:seating_undo]
    end

    test "undo restores a swap" do
      SeatAssignment.create!(rsvp: @rsvp_a, seating_table: @table, seat_position: 1)
      SeatAssignment.create!(rsvp: @rsvp_b, seating_table: @table, seat_position: 2)

      post move_admin_event_seating_path(@event),
           params: { rsvp_ids: [ @rsvp_a.id ], destination: { type: "seat", table_id: @table.id, position: 2 } },
           headers: turbo_headers

      post undo_admin_event_seating_path(@event), headers: turbo_headers

      assert_response :success
      assert_equal 1, SeatAssignment.find_by!(rsvp: @rsvp_a).seat_position
      assert_equal 2, SeatAssignment.find_by!(rsvp: @rsvp_b).seat_position
    end

    test "undo restores a bump (unseated guest returns to rail)" do
      SeatAssignment.create!(rsvp: @rsvp_a, seating_table: @table, seat_position: 1)
      # @rsvp_b is unseated. Drop b onto a's seat → bumps a.
      post move_admin_event_seating_path(@event),
           params: { rsvp_ids: [ @rsvp_b.id ], destination: { type: "seat", table_id: @table.id, position: 1 } },
           headers: turbo_headers
      assert_equal @rsvp_b.id, SeatAssignment.find_by(seating_table: @table, seat_position: 1).rsvp_id
      assert_nil SeatAssignment.find_by(rsvp: @rsvp_a)

      post undo_admin_event_seating_path(@event), headers: turbo_headers

      assert_response :success
      assert_equal @rsvp_a.id, SeatAssignment.find_by(seating_table: @table, seat_position: 1).rsvp_id
      assert_nil SeatAssignment.find_by(rsvp: @rsvp_b)
    end

    test "undo is a no-op when there is no snapshot" do
      post undo_admin_event_seating_path(@event), headers: turbo_headers

      assert_response :no_content
    end

    test "show clears unlocked assignments and preserves locked ones" do
      unlocked = SeatAssignment.create!(rsvp: @rsvp_a, seating_table: @table, seat_position: 1, locked: false)
      locked   = SeatAssignment.create!(rsvp: @rsvp_b, seating_table: @table, seat_position: 2, locked: true)

      get admin_event_seating_path(@event), headers: admin_auth

      assert_response :success
      assert_nil SeatAssignment.find_by(id: unlocked.id)
      assert SeatAssignment.find_by(id: locked.id), "locked assignment should survive"
    end

    test "Randomize's work survives the post-redirect show" do
      post randomize_admin_event_seating_path(@event), headers: admin_auth
      follow_redirect!(headers: admin_auth)

      assert_response :success
      assert SeatAssignment.find_by(rsvp: @rsvp_a), "Randomize-created assignment should survive the show clear"
    end
  end
end
