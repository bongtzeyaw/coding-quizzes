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

    OperationResult.new(success: true)
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

    OperationResult.new(success: true)
  end

  private

  def valid_account_number?(account_number)
    account_number.length.between?(ACCOUNT_NUMBER_MIN_LENGTH, ACCOUNT_NUMBER_MAX_LENGTH)
  end

  def valid_routing_number?(routing_number)
    routing_number.length == ROUTING_NUMBER_LENGTH
  end
end

class PaymentProcessLogger
  def self.log_validation_error(validation_result)
    puts "[#{Time.now}] ERROR: #{validation_result.info}"
  end

  def self.with_validation_logging(operation_title:, amount:)
    puts "[#{Time.now}] Starting #{operation_title} processing"
    puts "[#{Time.now}] Amount: #{amount}"

    yield

    puts "[#{Time.now}] Validation passed"
  end

  def self.with_processing_logging(operation_action_name:, transaction_id:)
    puts "[#{Time.now}] Processing #{operation_action_name}..."

    yield

    puts "[#{Time.now}] #{operation_action_name.capitalize} processed successfully"
    puts "[#{Time.now}] Transaction ID: #{transaction_id}"
  end
end

class PaymentProcessor
  def self.process_credit_card(amount:, card_number:, cvv:)
    process_operation(
      operation_title: 'credit card payment',
      operation_action_name: 'payment',
      transaction_prefix: 'TXN',
      validator: CreditCardValidator.new,
      validation_args: { amount:, card_number:, cvv: },
      processing_proc: -> { sleep(0.5) }
    )
  end

  def self.process_bank_transfer(amount:, account_number:, routing_number:)
    process_operation(
      operation_title: 'bank transfer',
      operation_action_name: 'transfer',
      transaction_prefix: 'BNK',
      validator: BankTransferValidator.new,
      validation_args: { amount:, account_number:, routing_number: },
      processing_proc: -> { sleep(1.0) }
    )
  end

  def self.process_operation(
    operation_title:,
    operation_action_name:,
    transaction_prefix:,
    validator:,
    validation_args:,
    processing_proc:
  )
    PaymentProcessLogger.with_validation_logging(operation_title:, amount: validation_args[:amount]) do
      validation_result = validator.validate(**validation_args)

      unless validation_result.success?
        PaymentProcessLogger.log_validation_error(validation_result)
        return validation_result.to_h
      end
    end

    transaction_id = "#{transaction_prefix}#{Time.now.to_i}"

    PaymentProcessLogger.with_processing_logging(operation_action_name:, transaction_id:) do
      processing_proc.call
    end

    OperationResult.new(success: true, transaction_id:).to_h
  end

  private_class_method :process_operation
end
