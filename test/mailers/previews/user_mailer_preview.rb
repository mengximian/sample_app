class UserMailerPreview < ActionMailer::Preview
  def account_activation
    user = User.new(name: "Preview User", email: "preview@example.com")
    user.activation_token = User.new_token
    UserMailer.account_activation(user)
  end
end
