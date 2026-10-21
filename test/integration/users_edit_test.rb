require "test_helper"

class UsersEditTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
  end

  test "unsuccessful edit shows all four errors without changing the user" do
    log_in_as(@user)
    get edit_user_path(@user)
    assert_template "users/edit"
    assert_select 'form[action=?] input[name=_method][value=patch]', user_path(@user)
    assert_select 'a[target=_blank][rel=noopener][href=?]', "https://gravatar.com/emails"

    original = @user.reload.attributes
    patch user_path(@user), params: { user: { name: "", email: "foo@invalid",
                                            password: "foo", password_confirmation: "bar" } }
    assert_response :unprocessable_entity
    assert_template "users/edit"
    assert_select "div.alert-danger", text: "The form contains 4 errors."
    assert_select "div#error_explanation li", count: 4
    assert_equal original, @user.reload.attributes
  end

  test "successful edit keeps password unchanged when both fields are empty" do
    log_in_as(@user)
    get edit_user_path(@user)
    digest = @user.password_digest
    patch user_path(@user), params: { user: { name: "Updated Name", email: "updated@example.net",
                                            password: "", password_confirmation: "" } }
    assert_redirected_to @user
    assert_equal "Profile updated", flash[:success]
    follow_redirect!
    assert_template "users/show"
    assert_equal "Updated Name", @user.reload.name
    assert_equal "updated@example.net", @user.email
    assert_equal digest, @user.password_digest
    assert is_logged_in?
  end

  test "successful edit can change the password" do
    log_in_as(@user)
    patch user_path(@user), params: { user: { password: "newpassword",
                                            password_confirmation: "newpassword" } }
    assert_redirected_to @user
    assert @user.reload.authenticate("newpassword")
    assert_not @user.authenticate("password")
  end

  test "friendly forwarding survives a failed login and is consumed once" do
    get edit_user_path(@user)
    assert_redirected_to login_url
    assert_equal edit_user_url(@user), session[:forwarding_url]
    log_in_as(@user, password: "invalid")
    assert_response :unprocessable_entity
    assert_equal edit_user_url(@user), session[:forwarding_url]

    log_in_as(@user)
    assert_redirected_to edit_user_url(@user)
    assert_nil session[:forwarding_url]
    follow_redirect!
    assert_template "users/edit"

    delete logout_path
    log_in_as(@user)
    assert_redirected_to @user
    assert_nil session[:forwarding_url]
  end

  test "friendly forwarding never grants access to another users edit page" do
    get edit_user_path(users(:archer))
    log_in_as(@user)
    follow_redirect!
    assert_response :see_other
    assert_redirected_to root_url
    assert_nil session[:forwarding_url]
  end
end
