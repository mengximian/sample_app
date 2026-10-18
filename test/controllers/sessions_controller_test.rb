require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get login_path
    assert_response :success
    assert_select "h1", "Log in"
    assert_select "form[action=?]", login_path
  end
end
