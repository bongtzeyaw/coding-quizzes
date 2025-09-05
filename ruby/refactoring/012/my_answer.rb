# frozen_string_literal: true

require 'active_support/security_utils'
require 'securerandom'

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

class PasswordVerifier
  class << self
    def verify(user:, password:)
      ActiveSupport::SecurityUtils.secure_compare(user.password, password)
      # If password hashing is implemented, do: ActiveSupport::SecurityUtils.secure_compare(user.password_digest, Digest::SHA256.hexdigest(password))
    end
  end
end

class SessionManager
  class << self
    SESSION_DURATION = 24 * 60 * 60 # 24時間

    def create_session(user)
      token = generate_token

      session = Session.new
      session.user_id = user.id
      session.token = token
      session.expires_at = Time.now + SESSION_DURATION
      session.save

      token
    end

    def destroy_session(token)
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
      return { valid: false } unless session

      if session_expired?(session)
        session.destroy
        { valid: false }
      else
        { valid: true, user_id: session.user_id }
      end
    end

    private

    def generate_token
      SecureRandom.urlsafe_base64(24)
    end

    def session_expired?(session)
      Time.now > session.expires_at
    end
  end
end

class AuthenticationService
  class << self
    def login(username:, password:)
      user = User.find_by(username:)
      return { success: false, error: 'Invalid credentials' } if user.nil?

      account_lock_manager = AccountLockManager.new(user)

      return account_lock_manager.handle_failed_attempt unless PasswordVerifier.verify(user:, password:)

      result = account_lock_manager.handle_successful_attempt
      return result unless result[:success]

      record_login(user)

      token = SessionManager.create_session(user)

      { success: true, token:, user: }
    end

    def logout(token)
      SessionManager.destroy_session(token)
    end

    def verify_token(token)
      SessionManager.verify_token(token)
    end

    private

    def record_login(user)
      user.last_login_at = Time.now
      user.save
    end
  end
end
