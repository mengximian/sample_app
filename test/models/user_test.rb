require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(name: "Example User", email: "user@example.com",
                     password: "foobar", password_confirmation: "foobar")
  end

  test "should be valid" do
    assert @user.valid?
  end

  test "new user still requires a password when it is nil" do
    @user.password = @user.password_confirmation = nil
    @user.password_digest = nil
    assert_not @user.valid?
  end

  test "admin defaults to false" do
    assert_not @user.admin?
  end

  test "name should be present" do
    @user.name = " "
    assert_not @user.valid?
  end

  test "name should not be too long" do
    @user.name = "a" * 51
    assert_not @user.valid?
  end

  test "email should be present" do
    @user.email = " "
    assert_not @user.valid?
  end

  test "email should not be too long" do
    @user.email = "a" * 244 + "@example.com"
    assert_not @user.valid?
  end

  test "email validation should accept valid addresses" do
    valid_addresses = %w[user@example.com USER@foo.COM
                         first.last@foo.jp alice+bob@baz.cn]
    valid_addresses.each do |address|
      @user.email = address
      assert @user.valid?, "#{address.inspect} should be valid"
    end
  end

  test "email validation should reject invalid addresses" do
    invalid_addresses = %w[user@example,com user_at_foo.org
                           user.name@example. foo@bar_baz.com foo@bar+baz.com]
    invalid_addresses.each do |address|
      @user.email = address
      assert_not @user.valid?, "#{address.inspect} should be invalid"
    end
  end

  test "email addresses should be unique" do
    duplicate_user = @user.dup
    @user.save!
    assert_not duplicate_user.valid?
  end

  test "email addresses should be saved as lower-case" do
    @user.email = "USER@EXAMPLE.COM"
    @user.save!
    assert_equal "user@example.com", @user.reload.email
  end

  test "password should be present (nonblank)" do
    @user.password = @user.password_confirmation = " " * 6
    assert_not @user.valid?
  end

  test "password should have a minimum length" do
    @user.password = @user.password_confirmation = "a" * 5
    assert_not @user.valid?
  end

  test "password authentication should work" do
    assert_equal @user, @user.authenticate("foobar")
    assert_not @user.authenticate("wrongpassword")
  end

  test "remember stores a digest and accepts only the matching token" do
    user = users(:michael)
    digest = user.remember
    token = user.remember_token
    assert token.present?
    assert_equal digest, user.reload.remember_digest
    assert_not_equal token, digest
    assert user.authenticated?(:remember, token)
    assert_not user.authenticated?(:remember, User.new_token)
    assert_nil User.find(user.id).remember_token
  end

  test "authenticated? returns false for a nil digest" do
    assert_not @user.authenticated?(:remember, "")
  end

  test "remember rotates the token and forget revokes it" do
    user = users(:michael)
    user.remember
    old_token = user.remember_token
    user.remember
    assert_not user.authenticated?(:remember, old_token)
    user.forget
    assert_nil user.reload.remember_digest
    assert_not user.authenticated?(:remember, old_token)
  end

  test "session token is stable until forgotten" do
    user = users(:michael)
    token = user.session_token
    assert_equal token, user.reload.session_token
    user.forget
    assert_not_equal token, user.reload.session_token
  end

  test "activation token is generated only on creation and is not persisted" do
    assert_nil @user.activation_token
    assert_nil @user.activation_digest
    @user.save!
    assert @user.activation_token.present?
    assert @user.authenticated?(:activation, @user.activation_token)
    assert_not @user.authenticated?(:activation, User.new_token)
    assert_not @user.activated?
    assert_nil @user.activated_at
    saved_digest = @user.activation_digest
    fresh = User.find(@user.id)
    assert_nil fresh.activation_token
    fresh.update!(name: "Changed")
    assert_equal saved_digest, fresh.reload.activation_digest
    assert_nil fresh.activation_token
    assert_raises(NoMethodError) { fresh.create_activation_digest }
  end

  test "activation nil digest is rejected" do
    assert_not @user.authenticated?(:activation, "")
  end

  test "activate writes both attributes once without changing updated_at" do
    @user.save!
    updated_at = @user.updated_at
    writes = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      sql = args.last[:sql]
      writes << sql if sql.start_with?("UPDATE")
    end
    begin
      @user.activate
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
    assert_equal 1, writes.size
    assert @user.reload.activated?
    assert_not_nil @user.activated_at
    assert_equal updated_at, @user.updated_at
  end
end
