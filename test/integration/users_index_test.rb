require "test_helper"

class UsersIndexTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:michael)
    @non_admin = users(:archer)
  end

  test "index as admin includes pagination, user partials and deletion links" do
    log_in_as(@admin)
    get users_path
    assert_template "users/index"
    assert_select "div.pagination", count: 2
    assert_select "ul.users > li", count: 30
    assert_select "ul.users img.gravatar[src*='?s=50']", count: 30
    User.where(activated: true).paginate(page: 1).each do |user|
      assert_select "ul.users a[href=?]", user_path(user), text: user.name
      if user == @admin
        assert_select "a[href=?]", user_path(user), text: "delete", count: 0
      else
        assert_select "a[href=?][data-turbo-method=delete][data-turbo-confirm]",
                      user_path(user), text: "delete", count: 1
      end
    end
  end

  test "second page contains only the remaining users and no self deletion link" do
    log_in_as(@admin)
    get users_path, params: { page: 2 }
    assert_response :success
    assert_select "div.pagination", count: 2
    assert_select "ul.users > li", count: User.where(activated: true).paginate(page: 2).length
    User.where(activated: true).paginate(page: 2).each do |user|
      assert_select "ul.users a[href=?]", user_path(user), text: user.name
    end
    assert_select "a[href=?]", user_path(@admin), text: "delete", count: 0
  end

  test "non admin index never exposes deletion links" do
    log_in_as(@non_admin)
    get users_path
    assert_response :success
    assert_select "a", text: "delete", count: 0
    assert_select "div.pagination", count: 2
  end

  test "successful deletion returns to a functioning index" do
    log_in_as(@admin)
    assert_difference "User.count", -1 do
      delete user_path(@non_admin)
    end
    assert_response :see_other
    assert_redirected_to users_url
    follow_redirect!
    assert_template "users/index"
    assert_select "div.alert-success", text: "User deleted"
    assert_select "ul.users a[href=?]", user_path(@non_admin), count: 0
  end

  test "nil page selects the first page" do
    assert_equal User.where(activated: true).paginate(page: 1).map(&:id), User.where(activated: true).paginate(page: nil).map(&:id)
    assert_equal 30, User.where(activated: true).paginate(page: nil).size
  end

  test "index excludes an inactive user that would otherwise be on the first page" do
    log_in_as(@admin)
    hidden = User.where(activated: true).paginate(page: 1).find { |user| user != @admin }
    hidden.update_columns(activated: false)
    get users_path
    assert_response :success
    assert_select "ul.users a[href=?]", user_path(hidden), count: 0
    assert_select "ul.users a[href=?]", user_path(users(:inactive)), count: 0
    assert assigns(:users).all?(&:activated?)
  end
end
