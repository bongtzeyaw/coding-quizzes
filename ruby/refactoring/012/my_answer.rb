# frozen_string_literal: true

class AccountLockManager
  LOCK_COOLDOWN_PERIOD = 30 * 60 # 30分
  LOCK_TRIGGER_FAILED_ATTEMPTS = 5

  def initialize(user)
    @user = user
  end

  def handle_failed_attempt
    record_failed_attempt

    if should_lock?
      lock_account
      { success: false, error: 'Account locked' }
    else
      { success: false, error: 'Invalid credentials' }
    end
  end

  def handle_successful_attempt
    return { success: false, error: 'Account locked' } if lock_active?

    unlock_account if locked?
    reset_failed_attempts

    { success: true }
  end

  private

  def record_failed_attempt
    @user.failed_attempts = 0 if @user.failed_attempts.nil?
    @user.failed_attempts += 1
    @user.last_failed_at = Time.now
    @user.save
  end

  def reset_failed_attempts
    @user.failed_attempts = 0
    @user.save
  end

  def locked?
    @user.locked
  end

  def lock_active?
    locked? && (Time.now - @user.locked_at <= LOCK_COOLDOWN_PERIOD)
  end

  def should_lock?
    @user.failed_attempts >= LOCK_TRIGGER_FAILED_ATTEMPTS
  end

  def lock_account
    @user.locked = true
    @user.locked_at = Time.now
    @user.save
  end

  def unlock_account
    @user.locked = false
    @user.failed_attempts = 0
    @user.save
  end
end

class AuthenticationService
  def login(username, password)
    user = User.find_by(username: username)
    return { success: false, error: 'Invalid credentials' } if user.nil?

    account_lock_manager = AccountLockManager.new(user)

    return account_lock_manager.handle_failed_attempt unless password_matches?(user.password, password)

    result = account_lock_manager.handle_successful_attempt
    return result unless result[:success]

    record_login(user)

    token = ''
    chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    32.times do
      token += chars[rand(chars.length)]
    end

    session = Session.new
    session.user_id = user.id
    session.token = token
    session.expires_at = Time.now + 86_400
    session.save

    { success: true, token: token, user: user }
  end

  def logout(token)
    session = Session.find_by(token: token)
    if session
      session.destroy
      { success: true }
    else
      { success: false, error: 'Invalid session' }
    end
  end

  def verify_token(token)
    session = Session.find_by(token: token)

    return { valid: false } if session.nil?

    if Time.now > session.expires_at
      session.destroy
      return { valid: false }
    end

    { valid: true, user_id: session.user_id }
  end

  private

  def password_matches?(user_password, password)
    user_password == password
  end

  def record_login(user)
    user.last_login_at = Time.now
    user.save
  end
end
