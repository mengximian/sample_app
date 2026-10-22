require "test_helper"

class PasswordResetsTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
    ActionMailer::Base.deliveries.clear
  end

  test "login links to the password reset request form" do
    get login_path
    assert_select "a[href=?]", new_password_reset_path, text: "(forgot password)"
    get new_password_reset_path
    assert_response :success
    assert_template "password_resets/new"
    assert_select 'form[action=?] input[name=?]', password_resets_path, "password_reset[email]"
  end

  test "unknown email does not send mail or change existing user" do
    ["", "missing@example.net"].each do |email|
      assert_no_changes -> { @user.reload.attributes } do
        post password_resets_path, params: { password_reset: { email: email } }
      end
      assert_response :unprocessable_entity
      assert_template "password_resets/new"
      assert_equal "Email address not found", flash[:danger]
      assert_empty ActionMailer::Base.deliveries
      assert_not is_logged_in?
      get root_path
      assert flash.empty?
    end
  end

  test "request stores reset attributes and sends exactly one mail without login" do
    post password_resets_path, params: { password_reset: { email: @user.email.upcase } }
    reset_user = assigns(:user)
    assert_redirected_to root_url
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal [@user.email], ActionMailer::Base.deliveries.last.to
    assert @user.reload.authenticated?(:reset, reset_user.reset_token)
    assert_not_nil @user.reset_sent_at
    assert_not is_logged_in?
    follow_redirect!
    assert_select "div.alert-info", text: "Email sent with password reset instructions"
  end

  test "email link opens a PATCH form with a top level email field" do
    request_reset
    get email_url
    assert_response :success
    assert_template "password_resets/edit"
    assert_select 'form[action=?] input[name=_method][value=patch]', password_reset_path(@reset_user.reset_token)
    assert_select 'input[type=hidden][name=email][value=?]', @user.email
    assert_select 'input[name=?]', "user[email]", count: 0
    assert_not is_logged_in?
  end

  test "new request invalidates the previous reset link" do
    request_reset
    old_token = @reset_user.reset_token
    request_reset
    assert_not @user.reload.authenticated?(:reset, old_token)
    get edit_password_reset_path(old_token, email: @user.email)
    assert_redirected_to root_url
    get edit_password_reset_path(@reset_user.reset_token, email: @user.email)
    assert_response :success
  end

  test "invalid tokens and email associations reject GET and direct PATCH" do
    request_reset
    [["wrong", @user.email], [@reset_user.reset_token, "unknown@example.net"],
     [@reset_user.reset_token, nil], [@reset_user.reset_token, users(:archer).email]].each do |token, email|
      get edit_password_reset_path(token, email: email)
      assert_redirected_to root_url
      assert_no_changes -> { @user.reload.attributes } do
        patch password_reset_path(token), params: { email: email,
                                                   user: { password: "newpassword", password_confirmation: "newpassword" } }
      end
      assert_redirected_to root_url
      assert_not is_logged_in?
    end
  end

  test "inactive user cannot use a valid reset token" do
    @user = users(:inactive)
    request_reset
    get edit_password_reset_path(@reset_user.reset_token, email: @user.email)
    assert_redirected_to root_url
    assert_no_changes -> { @user.reload.attributes } do
      patch password_reset_path(@reset_user.reset_token), params: reset_params("newpassword", "newpassword")
    end
    assert_redirected_to root_url
    assert_not @user.reload.activated?
    assert_not is_logged_in?
  end

  test "expired token rejects both GET and PATCH without changing password" do
    request_reset
    @user.update_column(:reset_sent_at, 3.hours.ago)
    get edit_password_reset_path(@reset_user.reset_token, email: @user.email)
    assert_redirected_to new_password_reset_url
    assert_no_changes -> { @user.reload.attributes } do
      patch password_reset_path(@reset_user.reset_token), params: reset_params("newpassword", "newpassword")
    end
    assert_redirected_to new_password_reset_url
    assert_not is_logged_in?
    follow_redirect!
    assert_match(/expired/i, response.body)
  end

  test "blank omitted short and mismatching passwords preserve the reset token" do
    request_reset
    [["", ""], [nil, ""], ["      ", "      "], ["short", "short"], ["newpassword", "different"]].each do |password, confirmation|
      attributes = @user.reload.attributes
      params = reset_params(password, confirmation)
      params[:user].delete(:password) if password.nil?
      patch password_reset_path(@reset_user.reset_token), params: params
      assert_response :unprocessable_entity
      assert_template "password_resets/edit"
      assert_select "div#error_explanation"
      assert_equal attributes, @user.reload.attributes
      assert_not is_logged_in?
    end
  end

  test "success resets password logs in clears session and rejects link reuse" do
    request_reset
    get edit_user_path(@user)
    assert_not_nil session[:forwarding_url]
    patch password_reset_path(@reset_user.reset_token), params: reset_params("newpassword", "newpassword")
    assert_redirected_to @user
    assert is_logged_in?
    assert_equal @user.id, session[:user_id]
    assert_equal @user.reload.remember_digest, session[:session_token]
    assert_nil session[:forwarding_url]
    assert_nil @user.reset_digest
    assert @user.authenticate("newpassword")
    assert_not @user.authenticate("password")
    follow_redirect!
    assert_template "users/show"
    assert_select "div.alert-success", text: "Password has been reset."

    delete logout_path
    get edit_password_reset_path(@reset_user.reset_token, email: @user.email)
    assert_redirected_to root_url
    assert_no_changes -> { @user.reload.password_digest } do
      patch password_reset_path(@reset_user.reset_token), params: reset_params("anotherpassword", "anotherpassword")
    end
    assert_redirected_to root_url
    assert_not is_logged_in?
    log_in_as(@user, password: "password")
    assert_response :unprocessable_entity
    assert_not is_logged_in?
    log_in_as(@user, password: "newpassword")
    assert is_logged_in?
  end

  test "reset endpoint cannot change profile authorization or token attributes" do
    request_reset
    original = @user.reload.attributes
    params = reset_params("newpassword", "newpassword")
    params[:user].merge!(name: "Forged", email: "forged@example.net", admin: false,
                         activated: false, activation_digest: "forged", reset_digest: "forged")
    patch password_reset_path(@reset_user.reset_token), params: params
    assert_redirected_to @user
    @user.reload
    %w[name email admin activated].each do |attribute|
      assert_equal original[attribute], @user[attribute]
    end
    assert_nil @user.activation_digest
    assert_nil @user.reset_digest
  end

  test "successful reset revokes the previous session and remember cookies" do
    log_in_as(@user)
    session_key = Rails.application.config.session_options[:key]
    old_session = cookies[session_key]
    old_user_cookie = cookies[:user_id]
    old_remember_token = cookies[:remember_token]
    old_digest = @user.reload.remember_digest
    request_reset
    patch password_reset_path(@reset_user.reset_token), params: reset_params("newpassword", "newpassword")
    assert is_logged_in?
    assert_not_equal old_digest, @user.reload.remember_digest
    assert_not @user.authenticated?(:remember, old_remember_token)

    replay = ActionDispatch::Integration::Session.new(Rails.application)
    replay.cookies[session_key] = old_session
    replay.get users_path
    assert_equal 303, replay.response.status
    assert_equal login_url, replay.response.location

    remembered = ActionDispatch::Integration::Session.new(Rails.application)
    remembered.cookies[:user_id] = old_user_cookie
    remembered.cookies[:remember_token] = old_remember_token
    remembered.get users_path
    assert_equal 303, remembered.response.status
    assert_equal login_url, remembered.response.location
  end

  private

  def request_reset
    post password_resets_path, params: { password_reset: { email: @user.email } }
    @reset_user = assigns(:user)
  end

  def email_url
    ActionMailer::Base.deliveries.last.text_part.body.decoded.lines.find { |line| line.start_with?("http") }.strip
  end

  def reset_params(password, confirmation)
    { email: @user.email, user: { password: password, password_confirmation: confirmation } }
  end
end
