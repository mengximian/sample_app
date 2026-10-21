require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
    @other_user = users(:archer)
  end

  test "should get new" do
    get signup_path
    assert_response :success
    assert_select "title", full_title("Sign up")
  end

  test "index requires login" do
    get users_path
    assert_response :see_other
    assert_redirected_to login_url
  end

  test "edit requires login and stores its location" do
    get edit_user_path(@user)
    assert_not flash.empty?
    assert_response :see_other
    assert_redirected_to login_url
    assert_equal edit_user_url(@user), session[:forwarding_url]
  end

  test "update requires login without storing a PATCH destination" do
    assert_no_changes -> { @user.reload.name } do
      patch user_path(@user), params: { user: { name: "Unauthorized" } }
    end
    assert_not flash.empty?
    assert_response :see_other
    assert_redirected_to login_url
    assert_nil session[:forwarding_url]
  end

  test "edit rejects the wrong user" do
    log_in_as(@other_user)
    get edit_user_path(@user)
    assert flash.empty?
    assert_response :see_other
    assert_redirected_to root_url
  end

  test "update rejects the wrong user" do
    log_in_as(@other_user)
    assert_no_changes -> { @user.reload.name } do
      patch user_path(@user), params: { user: { name: "Unauthorized" } }
    end
    assert flash.empty?
    assert_response :see_other
    assert_redirected_to root_url
  end

  test "admin attribute cannot be changed through update" do
    log_in_as(@other_user)
    assert_not @other_user.admin?
    patch user_path(@other_user), params: { user: { name: "Still ordinary", admin: true } }
    assert_redirected_to @other_user
    assert_equal "Still ordinary", @other_user.reload.name
    assert_not @other_user.admin?
  end

  test "signup cannot grant admin privileges" do
    assert_difference "User.count", 1 do
      post users_path, params: { user: { name: "New User", email: "new@example.net",
                                        password: "password", password_confirmation: "password",
                                        admin: true } }
    end
    assert_not User.find_by!(email: "new@example.net").admin?
  end

  test "destroy requires login" do
    assert_no_difference "User.count" do
      delete user_path(@other_user)
    end
    assert_response :see_other
    assert_redirected_to login_url
    assert_nil session[:forwarding_url]
  end

  test "destroy rejects non administrators" do
    log_in_as(@other_user)
    assert_no_difference "User.count" do
      delete user_path(@user)
    end
    assert_response :see_other
    assert_redirected_to root_url
  end

  test "administrator can destroy another user" do
    log_in_as(@user)
    assert_difference "User.count", -1 do
      delete user_path(@other_user)
    end
    assert_response :see_other
    assert_redirected_to users_url
    assert_equal "User deleted", flash[:success]
    assert_nil User.find_by(id: @other_user.id)
  end

  test "activation attributes cannot be set through signup or update" do
    post users_path, params: { user: { name: "Forged", email: "forged@example.net",
                                      password: "password", password_confirmation: "password",
                                      activated: true, activated_at: Time.zone.now,
                                      activation_digest: "forged" } }
    user = User.find_by!(email: "forged@example.net")
    assert_not user.activated?
    assert_nil user.activated_at
    assert_not_equal "forged", user.activation_digest

    log_in_as(@other_user)
    activated_at = @other_user.activated_at
    patch user_path(@other_user), params: { user: { activated: false, activated_at: nil,
                                                  activation_digest: "forged" } }
    assert_redirected_to @other_user
    assert @other_user.reload.activated?
    assert_equal activated_at, @other_user.activated_at
    assert_nil @other_user.activation_digest
  end
end
