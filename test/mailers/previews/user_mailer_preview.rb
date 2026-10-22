class UserMailerPreview < ActionMailer::Preview
  def password_reset
    user = User.new(name: "Preview User", email: "preview@example.com")
    user.reset_token = User.new_token
    UserMailer.password_reset(user)
  end

  def account_activation
    user = User.new(name: "Preview User", email: "preview@example.com")
    user.activation_token = User.new_token
    UserMailer.account_activation(user)
  end
end
