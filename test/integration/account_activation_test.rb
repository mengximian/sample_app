require "test_helper"

class AccountActivationTest < ActionDispatch::IntegrationTest
  def setup
    ActionMailer::Base.deliveries.clear
    post users_path, params: { user: { name: "Activation User", email: "activation@example.net",
                                      password: "password", password_confirmation: "password" } }
    @user = assigns(:user)
  end

  test "signup produces an inactive account and a usable activation email" do
    assert_not @user.activated?
    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal [@user.email], mail.to
    assert_includes mail.text_part.body.decoded, @user.activation_token
    assert_not_equal @user.activation_token, @user.activation_digest
  end

  test "inactive account cannot log in or obtain remember cookies" do
    ["0", "1"].each do |remember_me|
      log_in_as(@user, remember_me: remember_me)
      assert_redirected_to root_url
      assert_equal "Account not activated. Check your email for the activation link.", flash[:warning]
      assert_not is_logged_in?
      assert_nil session[:session_token]
      assert cookies[:remember_token].blank?
      assert cookies[:user_id].blank?
      assert_nil @user.reload.remember_digest
    end
  end

  test "invalid token does not activate or log in" do
    assert_no_changes -> { @user.reload.attributes } do
      get edit_account_activation_path("invalid", email: @user.email)
    end
    assert_redirected_to root_url
    assert_equal "Invalid activation link", flash[:danger]
    assert_not is_logged_in?
  end

  test "unknown or missing email does not activate or log in" do
    ["wrong@example.net", nil].each do |email|
      get edit_account_activation_path(@user.activation_token, email: email)
      assert_redirected_to root_url
      assert_not @user.reload.activated?
      assert_not is_logged_in?
    end
  end

  test "activation requires the token belonging to the email" do
    other = User.create!(name: "Other", email: "other-activation@example.net", password: "password")
    get edit_account_activation_path(@user.activation_token, email: other.email)
    assert_not other.reload.activated?
    assert_not @user.reload.activated?
    assert_not is_logged_in?
  end

  test "email link activates once and starts a replay-protected session" do
    url = ActionMailer::Base.deliveries.last.text_part.body.decoded.lines.find { |line| line.start_with?("http") }.strip
    get url
    assert @user.reload.activated?
    assert_not_nil @user.activated_at
    assert is_logged_in?
    assert_equal @user.id, session[:user_id]
    assert_equal @user.remember_digest, session[:session_token]
    assert_redirected_to @user
    follow_redirect!
    assert_template "users/show"
    assert_select "div.alert-success", text: "Account activated!"

    delete logout_path
    activated_at = @user.reload.activated_at
    assert_no_changes -> { @user.reload.remember_digest } do
      get url
    end
    assert_redirected_to root_url
    assert_not is_logged_in?
    assert_equal activated_at, @user.reload.activated_at
    assert_equal "Invalid activation link", flash[:danger]

    log_in_as(@user)
    assert is_logged_in?
    assert_redirected_to @user
  end
end
