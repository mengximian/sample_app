require "test_helper"

class UsersShowTest < ActionDispatch::IntegrationTest
  test "inactive profiles are not public" do
    get user_path(users(:inactive))
    assert_redirected_to root_url
    assert_not response.body.include?(users(:inactive).name)
  end

  test "activated profiles remain public" do
    get user_path(users(:archer))
    assert_response :success
    assert_template "users/show"
  end
end
