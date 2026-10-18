
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/reporters"
Minitest::Reporters.use!

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Include the ApplicationHelper in tests
  include ApplicationHelper

  # Returns true if a user is logged in during a test.
  def is_logged_in?
    !session[:user_id].nil?
  end

  # Logs in a user for controller and helper tests.
  def log_in_as(user)
    session[:user_id] = user.id
    session[:session_token] = user.session_token
  end
end

class ActionDispatch::IntegrationTest
  # Uses the real login endpoint so cookies and session are both exercised.
  def log_in_as(user, password: "password", remember_me: "1")
    post login_path, params: { session: { email: user.email,
                                        password: password,
                                        remember_me: remember_me } }
  end
end
