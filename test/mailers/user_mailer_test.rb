require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "activation email contains the recipient and absolute link in both formats" do
    user = users(:michael)
    user.activation_token = User.new_token
    mail = UserMailer.account_activation(user)
    assert_equal "Account activation", mail.subject
    assert_equal [user.email], mail.to
    assert_equal ["from@example.com"], mail.from
    assert mail.multipart?
    [mail.text_part, mail.html_part].each do |part|
      body = part.body.decoded
      assert_includes body, user.name
      assert_includes body, user.activation_token
      assert_includes body, CGI.escape(user.email)
      assert_includes body, "http://example.com/account_activations/"
    end
    assert_match(/^Date: /, mail.encoded)
    assert_not_nil mail.date
  end

  test "password reset email includes the absolute escaped link in both formats" do
    user = users(:michael)
    user.reset_token = User.new_token
    mail = UserMailer.password_reset(user)
    assert_equal "Password reset", mail.subject
    assert_equal [user.email], mail.to
    assert_equal ["from@example.com"], mail.from
    assert mail.multipart?
    [mail.text_part, mail.html_part].each do |part|
      body = part.body.decoded
      assert_includes body, Rails.application.routes.url_helpers.edit_password_reset_url(user.reset_token, email: user.email, host: "example.com")
      assert_includes body, CGI.escape(user.email)
      assert_includes body, "This link will expire in two hours."
    end
  end
end
