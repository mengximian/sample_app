require "test_helper"

class UsersSignupTest < ActionDispatch::IntegrationTest
  test "invalid signup information" do
    get signup_path
    assert_no_difference "User.count" do
      post users_path, params: {
        user: {
          name: "",
          email: "user@invalid",
          password: "foo",
          password_confirmation: "bar"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_template "users/new"
    assert_select "div#error_explanation"
    assert_select "div.alert-danger"
    assert_select "div#error_explanation li", minimum: 1
    assert_not is_logged_in?
  end

  test "valid signup information" do
    get signup_path
    assert_difference "User.count", 1 do
      post users_path, params: {
        user: {
          name: "Example User",
          email: "example-signup@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end
    assert_redirected_to user_url(User.last)
    follow_redirect!
    assert_template "users/show"
    assert_select "div.alert-success", text: "Welcome to the Sample App!"
    assert is_logged_in?
    assert_equal User.last.id, session[:user_id]
  end

end
