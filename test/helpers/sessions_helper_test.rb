require "test_helper"

class SessionsHelperTest < ActionController::TestCase
  tests SessionsController

  def setup
    @user = users(:michael)
  end

  test "current_user? checks identity and rejects nil" do
    assert_not @controller.current_user?(nil)
    assert_not @controller.current_user?(@user)
    log_in_as(@user)
    assert @controller.current_user?(@user)
    assert_not @controller.current_user?(users(:archer))
  end

  test "current_user restores the session from valid remember cookies" do
    @controller.remember(@user)
    assert_nil session[:user_id]
    assert_equal @user, @controller.current_user
    assert is_logged_in?
    assert_equal @user.reload.remember_digest, session[:session_token]
  end

  test "current_user rejects a mismatched remember digest" do
    @controller.remember(@user)
    @user.update_attribute(:remember_digest, User.digest(User.new_token))
    assert_nil @controller.current_user
    assert_not is_logged_in?
  end

  test "current_user rejects cookies revoked in another browser" do
    @controller.remember(@user)
    @user.forget
    assert_nil @controller.current_user
    assert_not is_logged_in?
  end

  test "current_user rejects a missing remember token" do
    @controller.remember(@user)
    @controller.send(:cookies).delete(:remember_token)
    assert_nil @controller.current_user
    assert_not is_logged_in?
  end

  test "current_user rejects cookies for a deleted user" do
    @controller.remember(@user)
    @user.destroy
    assert_nil @controller.current_user
    assert_not is_logged_in?
  end

  test "current_user rejects a tampered encrypted user id" do
    @controller.remember(@user)
    @controller.send(:cookies)[:user_id] = "tampered"
    assert_nil @controller.current_user
    assert_not is_logged_in?
  end

  test "current_user rejects an incorrect session token" do
    log_in_as(@user)
    session[:session_token] = "invalid"
    assert_nil @controller.current_user
  end

  test "current_user rejects a revoked session even after caching the user" do
    log_in_as(@user)
    assert_equal @user, @controller.current_user
    @user.forget
    assert_nil @controller.current_user
  end

  test "current_user prefers the session over another users remember cookie" do
    @controller.remember(@user)
    other_user = User.create!(name: "Other User", email: "other@example.com",
                              password: "password", password_confirmation: "password")
    log_in_as(other_user)
    assert_equal other_user, @controller.current_user
  end

  test "logout clears the session and cached current user" do
    user = users(:michael)
    @controller.log_in user
    assert_equal user, @controller.current_user
    assert @controller.logged_in?

    @controller.log_out
    assert_nil session[:user_id]
    assert_nil session[:session_token]
    assert_nil user.reload.remember_digest
    assert_nil @controller.instance_variable_get(:@current_user)
    assert_nil @controller.current_user
    assert_not @controller.logged_in?

    other_user = User.create!(name: "Other User", email: "other@example.com",
                              password: "password", password_confirmation: "password")
    @controller.log_in other_user
    assert_equal other_user, @controller.current_user
  end
end
