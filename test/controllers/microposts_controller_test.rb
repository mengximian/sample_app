require "test_helper"

class MicropostsControllerTest < ActionDispatch::IntegrationTest
  test "create requires login" do
    assert_no_difference "Micropost.count" do
      post microposts_path, params: { micropost: { content: "Unauthorized" } }
    end
    assert_response :see_other
    assert_redirected_to login_url
  end

  test "destroy requires login" do
    assert_no_difference "Micropost.count" do
      delete micropost_path(microposts(:orange))
    end
    assert_response :see_other
    assert_redirected_to login_url
  end

  test "even administrator cannot destroy another users micropost" do
    log_in_as(users(:michael))
    assert_no_difference "Micropost.count" do
      delete micropost_path(microposts(:ants))
    end
    assert_response :see_other
    assert_redirected_to root_url
  end

  test "create assigns ownership from current user rather than supplied user id" do
    user = users(:archer)
    log_in_as(user)
    assert_difference "Micropost.count", 1 do
      post microposts_path, params: { micropost: { content: "Owned post", user_id: users(:michael).id } }
    end
    assert_equal user, Micropost.first.user
  end

  test "destroy without referrer or from failed create redirects home" do
    user = users(:michael)
    log_in_as(user)
    [nil, microposts_url].each do |referrer|
      post = user.microposts.create!(content: "Delete me")
      assert_difference "Micropost.count", -1 do
        delete micropost_path(post), headers: referrer ? { "HTTP_REFERER" => referrer } : {}
      end
      assert_response :see_other
      assert_redirected_to root_url
    end
  end

  test "destroy with external referrer redirects home without an exception" do
    log_in_as(users(:michael))
    assert_difference "Micropost.count", -1 do
      delete micropost_path(microposts(:orange)), headers: { "HTTP_REFERER" => "https://external.example/" }
    end
    assert_response :see_other
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert_equal "Micropost deleted", flash[:success]
  end

  test "destroy returns to own profile when referrer is present" do
    user = users(:michael)
    log_in_as(user)
    delete micropost_path(microposts(:orange)), headers: { "HTTP_REFERER" => user_url(user) }
    assert_response :see_other
    assert_redirected_to user_url(user)
  end
end
