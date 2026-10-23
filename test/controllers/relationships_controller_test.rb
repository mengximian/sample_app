require "test_helper"

class RelationshipsControllerTest < ActionDispatch::IntegrationTest
  test "create and destroy require login for HTML and Turbo" do
    [nil, :turbo_stream].each do |format|
      assert_no_difference "Relationship.count" do
        post relationships_path(format: format), params: { followed_id: users(:archer).id }
      end
      assert_response :see_other
      assert_redirected_to login_url
      assert_no_difference "Relationship.count" do
        delete relationship_path(relationships(:one), format: format)
      end
      assert_response :see_other
      assert_redirected_to login_url
    end
  end

  test "create derives follower from session not supplied follower id" do
    user = users(:michael)
    other = users(:archer)
    log_in_as(user)
    assert_difference "Relationship.count", 1 do
      post relationships_path, params: { followed_id: other.id, follower_id: users(:malory).id }
    end
    assert user.following?(other)
    assert_not users(:malory).following?(other)
    assert_response :see_other
  end

  test "another users relationship cannot be destroyed even by admin" do
    log_in_as(users(:michael))
    [nil, :turbo_stream].each do |format|
      assert_no_difference "Relationship.count" do
        assert_raises ActiveRecord::RecordNotFound do
          delete relationship_path(relationships(:four), format: format)
        end
      end
    end
    assert Relationship.exists?(relationships(:four).id)
  end

  test "repeated follow and self follow do not create extra relationships" do
    user = users(:michael)
    log_in_as(user)
    [nil, :turbo_stream].each do |format|
      [users(:lana), user].each do |other|
        assert_no_difference "Relationship.count" do
          post relationships_path(format: format), params: { followed_id: other.id }
        end
        assert_response format ? :success : :see_other
      end
    end
    assert_not user.following?(user)
  end

  test "unknown user and unknown relationship return record not found" do
    log_in_as(users(:michael))
    assert_no_difference "Relationship.count" do
      assert_raises(ActiveRecord::RecordNotFound) { post relationships_path, params: { followed_id: 999999999 } }
      assert_raises(ActiveRecord::RecordNotFound) { delete relationship_path(999999999) }
    end
  end
end
