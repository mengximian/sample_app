require "test_helper"

class SiteLayoutTest < ActionDispatch::IntegrationTest
  test "layout links" do
    get root_path
    assert_template "static_pages/home"
    assert_select "a[href=?]", root_path, count: 2
    assert_select "a[href=?]", help_path
    assert_select "a[href=?]", about_path
    assert_select "a[href=?]", contact_path
    assert_select "a[href=?]", signup_path

    get contact_path
    assert_select "title", full_title("Contact")

    get signup_path
    assert_response :success
    assert_select "title", full_title("Sign up")
  end

  test "navigation reflects login status" do
    get root_path
    assert_select "a[href=?]", login_path, count: 1
    assert_select "a[href=?]", users_path, count: 0
    assert_select "a[href=?]", logout_path, count: 0

    user = users(:michael)
    log_in_as(user)
    follow_redirect!
    assert_select "a[href=?]", users_path, text: "Users", count: 1
    assert_select "a[href=?]", edit_user_path(user), text: "Settings", count: 1
    assert_select "header a[href=?]", user_path(user), text: "Profile", count: 1
    assert_select "a[href=?][data-turbo-method=delete]", logout_path, count: 1
    assert_select "a[href=?]", login_path, count: 0
  end
end
