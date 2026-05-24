require "test_helper"

module Admin
  class SeatingControllerTest < ActionDispatch::IntegrationTest
    def admin_auth
      { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "password") }
    end

    test "renders floorplan for welcome dinner" do
      get admin_event_seating_path(events(:welcome)), headers: admin_auth
      assert_response :success
      assert_select ".seating-table", count: 2 # welcome_t1, welcome_t2
      assert_select ".seating-table[data-table-name='T1'] .seat", count: 28
      assert_select ".seating-table[data-table-name='T2'] .seat", count: 34
    end

    test "renders curved table for reception" do
      get admin_event_seating_path(events(:reception)), headers: admin_auth
      assert_response :success
      assert_select ".seating-table--curve .seat", count: 24
    end

    test "index lists events with seating tables" do
      get admin_seating_path, headers: admin_auth
      assert_response :success
      assert_select "a[href=?]", admin_event_seating_path(events(:welcome))
      assert_select "a[href=?]", admin_event_seating_path(events(:reception))
    end

    test "randomize creates assignments and redirects" do
      event = events(:welcome)
      Rsvp.create!(guest: guests(:john_smith), event: event, attending: true)
      Rsvp.create!(guest: guests(:jane_smith), event: event, attending: true)

      post randomize_admin_event_seating_path(event), headers: admin_auth

      assert_redirected_to admin_event_seating_path(event)
      assert SeatAssignment.joins(:seating_table).where(seating_tables: { event_id: event.id }).exists?
    end

    test "randomize preserves locked assignments" do
      event = events(:welcome)
      rsvp = Rsvp.create!(guest: guests(:john_smith), event: event, attending: true)
      table = event.seating_tables.first
      locked = SeatAssignment.create!(rsvp: rsvp, seating_table: table, seat_position: 5, locked: true)

      post randomize_admin_event_seating_path(event), headers: admin_auth

      locked.reload
      assert locked.locked
      assert_equal 5, locked.seat_position
    end
  end
end
