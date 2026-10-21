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
end
