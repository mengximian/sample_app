require "test_helper"

class UsersSignup < ActionDispatch::IntegrationTest
  def setup
    ActionMailer::Base.deliveries.clear
  end
end

class UsersSignupTest < UsersSignup
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
    assert_empty ActionMailer::Base.deliveries
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
    assert_redirected_to root_url
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not User.last.activated?
    assert_nil User.last.activated_at
    assert_not is_logged_in?
    follow_redirect!
    assert_template "static_pages/home"
    assert_select "div.alert-info", text: "Please check your email to activate your account."
  end

end
