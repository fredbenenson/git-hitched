require "test_helper"

class ChildrenPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    authenticate_gate!
    @invite = invites(:johnsons)
    @child = Guest.create!(invite: @invite, first_name: "Sam", is_child: true, age: 4)
    @token = @invite.children_preferences_token
  end

  test "shows the preferences page for a valid token" do
    get children_preferences_path(token: @token)
    assert_response :success
    assert_select "h1", /little ones/i
  end

  test "redirects an invalid token back to the RSVP lookup" do
    get children_preferences_path(token: "garbage")
    assert_redirected_to rsvp_path
  end

  test "saves highchair and reception seating preferences" do
    patch update_children_preferences_path(token: @token), params: {
      children: { @child.id.to_s => { needs_highchair: "1", reception_seating: "kids_area" } }
    }
    assert_redirected_to children_preferences_path(token: @token)
    @child.reload
    assert @child.needs_highchair?
    assert @child.seated_kids_area?
  end

  test "notifies the admin after saving" do
    assert_enqueued_email_with RsvpMailer, :children_preferences_notification, args: [ @invite ] do
      patch update_children_preferences_path(token: @token), params: {
        children: { @child.id.to_s => { needs_highchair: "0" } }
      }
    end
  end
end
