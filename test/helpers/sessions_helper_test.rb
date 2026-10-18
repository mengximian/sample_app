require "test_helper"

class SessionsHelperTest < ActionController::TestCase
  tests SessionsController

  test "logout clears the session and cached current user" do
    user = users(:michael)
    @controller.log_in user
    assert_equal user, @controller.current_user
    assert @controller.logged_in?

    @controller.log_out
    assert_nil session[:user_id]
    assert_nil @controller.current_user
    assert_not @controller.logged_in?

    other_user = User.create!(name: "Other User", email: "other@example.com",
                              password: "password", password_confirmation: "password")
    @controller.log_in other_user
    assert_equal other_user, @controller.current_user
  end
end
