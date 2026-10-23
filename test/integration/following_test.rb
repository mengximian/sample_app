require "test_helper"

class FollowingTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
    @other = users(:archer)
    log_in_as(@user)
  end

  test "follow and unfollow standard HTML requests redirect to target" do
    assert_difference "@user.following.count", 1 do
      post relationships_path, params: { followed_id: @other.id }
    end
    assert_response :see_other
    assert_redirected_to @other
    follow_redirect!
    assert_select "#follow_form input[value=Unfollow]", count: 1
    relationship = @user.active_relationships.find_by!(followed_id: @other.id)
    assert_difference "@user.following.count", -1 do
      delete relationship_path(relationship)
    end
    assert_response :see_other
    assert_redirected_to @other
    follow_redirect!
    assert_select "#follow_form input[value=Follow]", count: 1
  end

  test "Turbo updates form and accurate follower count without redirect" do
    assert_difference "@user.following.count", 1 do
      post relationships_path(format: :turbo_stream), params: { followed_id: @other.id }
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select 'turbo-stream[action=update][target=follow_form] template input[value=Unfollow]', count: 1
    assert_select 'turbo-stream[target=followers] template', text: @other.followers.count.to_s
    relationship = @user.active_relationships.find_by!(followed_id: @other.id)
    assert_difference "@user.following.count", -1 do
      delete relationship_path(relationship, format: :turbo_stream)
    end
    assert_response :success
    assert_select 'turbo-stream[action=update][target=follow_form] template input[value=Follow]', count: 1
    assert_select 'turbo-stream[target=followers] template', text: @other.followers.count.to_s
  end

  test "following and followers require login and exclude inactive profiles" do
    delete logout_path
    [following_user_path(@user), followers_user_path(@user)].each do |path|
      get path
      assert_response :see_other
      assert_redirected_to login_url
    end
    log_in_as(@user)
    inactive = users(:inactive)
    Relationship.create!(follower: @user, followed: inactive)
    inactive.follow(@user)
    [following_user_path(inactive), followers_user_path(inactive)].each do |path|
      get path
      assert_redirected_to root_url
    end
    [following_user_path(@user), followers_user_path(@user)].each do |path|
      get path
      assert_response :success
      assert_select 'ul.users a[href=?]', user_path(inactive), count: 0
    end
  end

  test "following and followers pages paginate lists and sidebar avatars" do
    users = 30.times.map { |n| users("user_#{n}") }
    users.each { |user| @user.follow(user); user.follow(@user) }
    [[following_user_path(@user), @user.following], [followers_user_path(@user), @user.followers]].each do |path, collection|
      assert_not collection.empty?
      get path
      assert_response :success
      assert_select "ul.users.follow > li", count: 30
      assert_select "div.pagination", count: 1
      assert_select ".user_avatars a", count: 30
      collection.paginate(page: 1).each { |user| assert_select 'ul.users a[href=?]', user_path(user) }
      get path, params: { page: 2 }
      assert_select "ul.users.follow > li", count: collection.paginate(page: 2).length
    end
  end

  test "stats and follow forms show correct user with no self or guest button" do
    get root_path
    assert_select '#following', text: @user.following.count.to_s
    assert_select '#followers', text: @user.followers.count.to_s
    get user_path(@other)
    assert_select '#follow_form input[value=Follow]', count: 1
    assert_select '#following', text: @other.following.count.to_s
    assert_select '#followers', text: @other.followers.count.to_s
    get user_path(@user)
    assert_select '#follow_form', count: 0
    delete logout_path
    get user_path(@other)
    assert_select '#follow_form', count: 0
  end

  test "Home feed shows own and followed content escaped once with pagination" do
    post = users(:lana).microposts.create!(content: '<b>following & feed</b>')
    get root_path
    assert_select 'ol.microposts > li', count: 30
    assert_select "li#micropost-#{post.id} .content", text: post.content
    assert_includes response.body, CGI.escapeHTML(post.content)
    assert_select "li#micropost-#{post.id} .content b", count: 0
    @user.feed.paginate(page: 1).each do |micropost|
      assert_select "li#micropost-#{micropost.id} .content", text: micropost.content
    end
    assert_select "li#micropost-#{microposts(:ants).id}", count: 0
    get root_path, params: { page: 2 }
    assert_select 'ol.microposts > li', count: @user.feed.paginate(page: 2).length
  end

  test "public following and follower statistics match their activated lists" do
    inactive = users(:inactive)
    Relationship.create!(follower: @user, followed: inactive)
    Relationship.create!(follower: inactive, followed: @user)
    [[following_user_path(@user), "following", @user.following],
     [followers_user_path(@user), "followers", @user.followers]].each do |path, id, relation|
      expected = relation.where(activated: true).count
      get path
      assert_response :success
      assert_select "##{id}", text: expected.to_s
      assert_select "ul.users.follow > li", count: expected
      assert_select 'ul.users.follow a[href=?]', user_path(inactive), count: 0
    end
    get root_path
    assert_select '#following', text: @user.following.where(activated: true).count.to_s
    assert_select '#followers', text: @user.followers.where(activated: true).count.to_s
    get user_path(@user)
    assert_select '#following', text: @user.following.where(activated: true).count.to_s
    assert_select '#followers', text: @user.followers.where(activated: true).count.to_s
  end

  test "direct follow of inactive user is refused for HTML and Turbo without changing data" do
    inactive = users(:inactive)
    before = inactive.attributes
    [nil, :turbo_stream].each do |format|
      assert_no_difference ["Relationship.count", "Micropost.count"] do
        post relationships_path(format: format), params: { followed_id: inactive.id }
      end
      assert_response :see_other
      assert_redirected_to root_url
      assert_not @user.following?(inactive)
      assert_equal before, inactive.reload.attributes
    end
  end

  test "deactivation hides followed posts without deleting relationships or microposts" do
    followed = users(:lana)
    relationship = @user.active_relationships.find_by!(followed_id: followed.id)
    micropost = followed.microposts.first!
    get root_path
    assert_select "li#micropost-#{micropost.id}", count: 1
    followed.update_columns(activated: false)
    before = followed.attributes
    assert_no_difference ["Relationship.count", "Micropost.count"] do
      get root_path
      assert_response :success
      assert_select "li#micropost-#{micropost.id}", count: 0
      assert_select "li#micropost-#{microposts(:orange).id}", count: 1
      assert_select '#following', text: @user.following.where(activated: true).count.to_s
    end
    assert Relationship.exists?(relationship.id)
    assert Micropost.exists?(micropost.id)
    assert_equal before, followed.reload.attributes
  end

  test "HTML and Turbo follow counts exclude inactive followers and match the list" do
    inactive = users(:inactive)
    Relationship.create!(follower: inactive, followed: @other)
    inactive_before = inactive.attributes
    [nil, :turbo_stream].each do |format|
      assert_difference "Relationship.count", 1 do
        post relationships_path(format: format), params: { followed_id: @other.id }
      end
      expected = @other.followers.where(activated: true).count
      if format
        assert_response :success
        assert_select 'turbo-stream[target=followers] template', text: expected.to_s
      else
        assert_response :see_other
        follow_redirect!
        assert_select '#followers', text: expected.to_s
      end
      get followers_user_path(@other)
      assert_select '#followers', text: expected.to_s
      assert_select 'ul.users.follow > li', count: expected
      relationship = @user.active_relationships.find_by!(followed_id: @other.id)
      assert_difference "Relationship.count", -1 do
        delete relationship_path(relationship, format: format)
      end
      expected = @other.followers.where(activated: true).count
      if format
        assert_response :success
        assert_select 'turbo-stream[target=followers] template', text: expected.to_s
      else
        assert_response :see_other
        follow_redirect!
        assert_select '#followers', text: expected.to_s
      end
      get followers_user_path(@other)
      assert_select '#followers', text: expected.to_s
      assert_select 'ul.users.follow > li', count: expected
    end
    assert Relationship.exists?(follower: inactive, followed: @other)
    assert_equal inactive_before, inactive.reload.attributes
  end
end
