require "test_helper"

class UsersLoginTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
  end

  test "login with invalid information" do
    get login_path
    assert_template "sessions/new"

    post login_path, params: {
      session: { email: "", password: "" }
    }

    assert_response :unprocessable_entity
    assert_not is_logged_in?
    assert_template "sessions/new"
    assert_not flash.empty?

    get root_path
    assert flash.empty?
  end

  test "login with valid email and invalid password" do
    post login_path, params: {
      session: { email: @user.email, password: "wrongpassword" }
    }
    assert_response :unprocessable_entity
    assert_not is_logged_in?
    assert_template "sessions/new"
    assert_select "div.alert-danger", text: "Invalid email/password combination"
    get root_path
    assert flash.empty?
  end

  test "login with valid information followed by logout" do
    get login_path
    post login_path, params: {
      session: { email: @user.email.upcase, password: "password" }
    }
    assert is_logged_in?
    assert_equal @user.id, session[:user_id]
    assert_redirected_to @user
    follow_redirect!
    assert_template "users/show"
    assert_select "a[href=?]", login_path, count: 0
    assert_select "a[href=?][data-turbo-method=delete]", logout_path, count: 1
    assert_select "a[href=?]", user_path(@user), count: 1

    delete logout_path
    assert_not is_logged_in?
    assert_response :see_other
    assert_redirected_to root_url
    follow_redirect!
    assert_select "a[href=?]", login_path, count: 1
    assert_select "a[href=?]", logout_path, count: 0
    assert_select "a[href=?]", user_path(@user), count: 0
  end
end
