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
    assert_select "header a[href=?]", user_path(@user), count: 1

    delete logout_path
    assert_not is_logged_in?
    assert_response :see_other
    assert_redirected_to root_url
    follow_redirect!
    assert_select "a[href=?]", login_path, count: 1
    assert_select "a[href=?]", logout_path, count: 0
    assert_select "header a[href=?]", user_path(@user), count: 0

    # A second tab may still show its old logout link.
    delete logout_path
    assert_response :see_other
    assert_redirected_to root_url
    assert_not is_logged_in?
  end

  test "login form offers the remember me checkbox" do
    get login_path
    assert_select 'input[type=checkbox][name="session[remember_me]"][value="1"]', count: 1
    assert_select 'input[type=hidden][name="session[remember_me]"][value="0"]', count: 1
    assert_select 'label[for=session_remember_me]', text: "Remember me on this computer"
  end

  test "login with remembering stores the actual token and encrypted user id" do
    log_in_as(@user)
    assert is_logged_in?
    assert_equal assigns(:user).remember_token, cookies[:remember_token]
    assert @user.reload.authenticated?(:remember, cookies[:remember_token])
    assert cookies[:user_id].present?
    assert_not_equal @user.id.to_s, cookies[:user_id]
    assert_equal @user.remember_digest, session[:session_token]
    assert response.headers["Set-Cookie"].include?("expires=")
  end

  test "login without remembering clears old remember cookies" do
    log_in_as(@user, remember_me: "1")
    old_digest = @user.reload.remember_digest
    assert cookies[:remember_token].present?
    log_in_as(@user, remember_me: "0")
    assert is_logged_in?
    assert cookies[:remember_token].blank?
    assert cookies[:user_id].blank?
    # The replay guard needs a digest even for a temporary session.
    assert_not_equal old_digest, @user.reload.remember_digest
    assert_equal @user.remember_digest, session[:session_token]
  end

  test "logout revokes remember cookies and prevents replay of the old session" do
    log_in_as(@user)
    session_key = Rails.application.config.session_options[:key]
    old_session_cookie = cookies[session_key]
    assert old_session_cookie.present?

    delete logout_path
    assert_response :see_other
    assert_not is_logged_in?
    assert_nil @user.reload.remember_digest
    assert cookies[:remember_token].blank?
    assert cookies[:user_id].blank?

    cookies[session_key] = old_session_cookie
    get root_path
    assert_select "a[href=?]", login_path, count: 1
    assert_select "a[href=?]", logout_path, count: 0
  end

  test "invalid login does not create remember cookies" do
    log_in_as(@user, password: "invalid")
    assert_response :unprocessable_entity
    assert_not is_logged_in?
    assert cookies[:remember_token].blank?
    assert cookies[:user_id].blank?
    assert_nil @user.reload.remember_digest
  end

  test "remember cookies restore login when the temporary session ends" do
    log_in_as(@user)
    session_key = Rails.application.config.session_options[:key]
    cookies.delete(session_key)

    get root_path
    assert is_logged_in?
    assert_equal @user.id, session[:user_id]
    assert_equal @user.reload.remember_digest, session[:session_token]
    assert_select "a[href=?]", logout_path, count: 1
  end

  test "temporary login is not restored without a session cookie" do
    log_in_as(@user, remember_me: "0")
    cookies.delete(Rails.application.config.session_options[:key])

    get root_path
    assert_not is_logged_in?
    assert_select "a[href=?]", login_path, count: 1
    assert_select "a[href=?]", logout_path, count: 0
  end
end
