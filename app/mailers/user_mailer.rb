class UserMailer < ApplicationMailer
  def password_reset(user)
    @user = user
    mail to: user.email, subject: "Password reset"
  end

  def account_activation(user)
    @user = user
    mail to: user.email, subject: "Account activation"
  end
end
