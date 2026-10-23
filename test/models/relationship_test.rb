require "test_helper"

class RelationshipTest < ActiveSupport::TestCase
  def setup
    @relationship = Relationship.new(follower: users(:michael), followed: users(:archer))
  end

  test "valid relationship resolves both users" do
    assert @relationship.valid?
    assert_equal users(:michael), @relationship.follower
    assert_equal users(:archer), @relationship.followed
  end

  test "both user ids and existing users are required" do
    [:follower, :followed].each do |attribute|
      relationship = @relationship.dup
      relationship.public_send("#{attribute}=", nil)
      assert_not relationship.valid?
      relationship.public_send("#{attribute}_id=", 999999999)
      assert_not relationship.valid?
    end
  end

  test "database rejects duplicate pairs but permits reverse direction" do
    @relationship.save!
    assert_raises ActiveRecord::RecordNotUnique do
      Relationship.create!(follower: @relationship.follower, followed: @relationship.followed)
    end
    assert Relationship.exists?(follower: users(:archer), followed: users(:michael))
  end

  test "migration has both lookup indexes and unique pair index" do
    indexes = Relationship.connection.indexes(:relationships)
    assert indexes.any? { |index| index.columns == ["follower_id"] }
    assert indexes.any? { |index| index.columns == ["followed_id"] }
    assert indexes.any? { |index| index.columns == ["follower_id", "followed_id"] && index.unique }
  end
end
