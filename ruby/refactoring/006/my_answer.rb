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
    operation_title = 'credit card payment'
    operation_action_name = 'payment'

    with_logging_for_validation_phase(operation_title:, amount:) do
      credit_card_validator = CreditCardValidator.new
      credit_card_validation_result = credit_card_validator.validate(card_number:, cvv:, amount:)

      unless credit_card_validation_result.success?
        log_validation_error(credit_card_validation_result)
        return credit_card_validation_result.to_h
      end
    end

    transaction_id = "TXN#{Time.now.to_i}"

    with_logging_for_processing_phase(operation_action_name:, transaction_id:) do
      sleep(0.5)
    end

    OperationResult.new(success: true, transaction_id:).to_h
  end

  def process_bank_transfer(amount, account_number, routing_number)
    operation_title = 'bank transfer'
    operation_action_name = 'transfer'

    with_logging_for_validation_phase(operation_title:, amount:) do
      bank_transfer_validator = BankTransferValidator.new
      bank_transfer_validation_result = bank_transfer_validator.validate(account_number:, routing_number:, amount:)

      unless bank_transfer_validation_result.success?
        log_validation_error(bank_transfer_validation_result)
        return bank_transfer_validation_result.to_h
      end
    end

    transaction_id = "BNK#{Time.now.to_i}"

    with_logging_for_processing_phase(operation_action_name:, transaction_id:) do
      sleep(1.0)
    end

    OperationResult.new(success: true, transaction_id:).to_h
  end

  private

  def log_validation_error(validation_result)
    puts "[#{Time.now}] ERROR: #{validation_result.info}"
  end

  def with_logging_for_validation_phase(operation_title:, amount:)
    puts "[#{Time.now}] Starting #{operation_title} processing"
    puts "[#{Time.now}] Amount: #{amount}"

    yield

    puts "[#{Time.now}] Validation passed"
  end

  def with_logging_for_processing_phase(operation_action_name:, transaction_id:)
    puts "[#{Time.now}] Processing #{operation_action_name}..."

    yield

    puts "[#{Time.now}] #{operation_action_name.capitalize} processed successfully"
    puts "[#{Time.now}] Transaction ID: #{transaction_id}"
  end
end
