# frozen_string_literal: true

class OperationResult
  def initialize(success:, **info)
    @success = success
    @info = info
  end

  def success?
    @success
  end

  def info
    @info.values.join('; ')
  end

  def to_h
    { success: @success }.merge(@info)
  end
end

class PaymentValidator
  AMOUNT_MIN = 0

  protected

  def valid_amount?(amount)
    amount > AMOUNT_MIN
  end
end

class CreditCardValidator < PaymentValidator
  CARD_NUMBER_LENGTH = 16
  CVV_LENGTH = 3

  def validate(card_number:, cvv:, amount:)
    return OperationResult.new(success: false, error: 'Invalid card number') unless valid_card_number?(card_number)
    return OperationResult.new(success: false, error: 'Invalid CVV') unless valid_cvv?(cvv)
    return OperationResult.new(success: false, error: 'Invalid amount') unless valid_amount?(amount)

    OperationResult.new(success: true, message: 'Validation passed')
  end

  private

  def valid_card_number?(card_number)
    card_number.length == CARD_NUMBER_LENGTH
  end

  def valid_cvv?(cvv)
    cvv.length == CVV_LENGTH
  end
end

class BankTransferValidator < PaymentValidator
  ROUTING_NUMBER_LENGTH = 9
  ACCOUNT_NUMBER_MIN_LENGTH = 8
  ACCOUNT_NUMBER_MAX_LENGTH = 12

  def validate(account_number:, routing_number:, amount:)
    return OperationResult.new(success: false, error: 'Invalid account number') unless valid_account_number?(account_number)
    return OperationResult.new(success: false, error: 'Invalid routing number') unless valid_routing_number?(routing_number)
    return OperationResult.new(success: false, error: 'Invalid amount') unless valid_amount?(amount)

    OperationResult.new(success: true, message: 'Validation passed')
  end

  private

  def valid_account_number?(account_number)
    account_number.length.between?(ACCOUNT_NUMBER_MIN_LENGTH, ACCOUNT_NUMBER_MAX_LENGTH)
  end

  def valid_routing_number?(routing_number)
    routing_number.length == ROUTING_NUMBER_LENGTH
  end
end

class PaymentProcessor
  def process_credit_card(amount, card_number, cvv)
    puts "[#{Time.now}] Starting credit card payment processing"
    puts "[#{Time.now}] Amount: #{amount}"

    credit_card_validator = CreditCardValidator.new
    credit_card_validation_result = credit_card_validator.validate(card_number:, cvv:, amount:)

    unless credit_card_validation_result.success?
      puts "[#{Time.now}] ERROR: #{credit_card_validation_result.info}"
      return credit_card_validation_result.to_h
    end

    puts "[#{Time.now}] Validation passed"

    transaction_id = "TXN#{Time.now.to_i}"
    puts "[#{Time.now}] Processing payment..."
    sleep(0.5)

    puts "[#{Time.now}] Payment processed successfully"
    puts "[#{Time.now}] Transaction ID: #{transaction_id}"

    { success: true, transaction_id: transaction_id }
  end

  def process_bank_transfer(amount, account_number, routing_number)
    puts "[#{Time.now}] Starting bank transfer processing"
    puts "[#{Time.now}] Amount: #{amount}"

    bank_transfer_validator = BankTransferValidator.new
    bank_transfer_validation_result = bank_transfer_validator.validate(account_number:, routing_number:, amount:)

    unless bank_transfer_validation_result.success?
      puts "[#{Time.now}] ERROR: #{bank_transfer_validation_result.info}"
      return bank_transfer_validation_result.to_h
    end

    puts "[#{Time.now}] Validation passed"

    transaction_id = "BNK#{Time.now.to_i}"
    puts "[#{Time.now}] Processing transfer..."
    sleep(1.0)

    puts "[#{Time.now}] Transfer processed successfully"
    puts "[#{Time.now}] Transaction ID: #{transaction_id}"

    { success: true, transaction_id: transaction_id }
  end
end
