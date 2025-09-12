require 'minitest/autorun'
require_relative 'my_answer'

class User
  attr_accessor :id, :username, :password, :failed_attempts, :last_failed_at, :locked, :locked_at, :last_login_at

  def initialize(id:, username:, password:)
    @id = id
    @username = username
    @password = password
    @failed_attempts = 0
    @locked = false
  end

  def save
    true
  end

  def self.find_by(username:)
    @@users ||= {}
    @@users[username]
  end

  def self.add(user)
    @@users ||= {}
    @@users[user.username] = user
  end
end

class Session
  attr_accessor :user_id, :token, :expires_at

  def save
    self.class.sessions[token] = self
    true
  end

  def destroy
    self.class.sessions.delete(token)
  end

  def self.find_by(token:)
    sessions[token]
  end

  def self.sessions
    @@sessions ||= {}
  end
end

class AuthenticationServiceTest < Minitest::Test
  def setup
    @user = User.new(id: 1, username: 'testuser', password: 'password')
    User.add(@user)
  end

  def test_login_success
    result = AuthenticationService.login(username: 'testuser', password: 'password')
    assert result[:success]
    refute_nil result[:token]
    assert_equal @user, result[:user]
  end

  def test_login_invalid_username
    result = AuthenticationService.login(username: 'unknown', password: 'password')
    refute result[:success]
    assert_equal 'Invalid credentials', result[:error]
  end

  def test_login_invalid_password
    result = AuthenticationService.login(username: 'testuser', password: 'wrong')
    refute result[:success]
    assert_equal 'Invalid credentials', result[:error]
    assert_equal 1, @user.failed_attempts
  end

  def test_account_locks_after_five_failed_attempts
    5.times { AuthenticationService.login(username: 'testuser', password: 'wrong') }
    result = AuthenticationService.login(username: 'testuser', password: 'wrong')
    refute result[:success]
    assert_equal 'Account locked', result[:error]
    assert @user.locked
  end

  def test_locked_account_login_within_30_minutes
    @user.locked = true
    @user.locked_at = Time.now
    result = AuthenticationService.login(username: 'testuser', password: 'password')
    refute result[:success]
    assert_equal 'Account locked', result[:error]
  end

  def test_locked_account_login_after_30_minutes
    @user.locked = true
    @user.locked_at = Time.now - 1900
    result = AuthenticationService.login(username: 'testuser', password: 'password')
    assert result[:success]
    assert_equal @user, result[:user]
    refute @user.locked
  end

  def test_logout_success
    login_result = AuthenticationService.login(username: 'testuser', password: 'password')
    token = login_result[:token]
    result = AuthenticationService.logout(token)
    assert result[:success]
    assert_nil Session.find_by(token: token)
  end

  def test_logout_invalid_token
    result = AuthenticationService.logout('badtoken')
    refute result[:success]
    assert_equal 'Invalid session', result[:error]
  end

  def test_verify_token_success
    login_result = AuthenticationService.login(username: 'testuser', password: 'password')
    token = login_result[:token]
    result = AuthenticationService.verify_token(token)
    assert result[:valid]
    assert_equal @user.id, result[:user_id]
  end

  def test_verify_token_expired
    login_result = AuthenticationService.login(username: 'testuser', password: 'password')
    token = login_result[:token]
    session = Session.find_by(token: token)
    session.expires_at = Time.now - 10
    result = AuthenticationService.verify_token(token)
    refute result[:valid]
    assert_nil Session.find_by(token: token)
  end

  def test_verify_token_invalid
    result = AuthenticationService.verify_token('badtoken')
    refute result[:valid]
  end
end
