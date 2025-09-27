# frozen_string_literal: true

class Transaction
  attr_reader :type, :amount

  def initialize(amount:, balance_after:)
    @type = self.class::TYPE
    @amount = amount
    @timestamp = Time.now.utc
    @balance_after = balance_after
  end

  def to_h
    instance_variables.each_with_object({}) do |var, hash|
      hash[var.to_s.delete('@').to_sym] = instance_variable_get(var)
    end
  end
end

class DepositTransaction < Transaction
  TYPE = 'deposit'
end

class WithdrawTransaction < Transaction
  TYPE = 'withdraw'
end

class TransferOutTransaction < Transaction
  TYPE = 'transfer_out'

  def initialize(amount:, balance_after:, target:)
    super(amount:, balance_after:)
    @target = target
  end
end

class TransferInTransaction < Transaction
  TYPE = 'transfer_in'

  def initialize(amount:, balance_after:, source:)
    super(amount:, balance_after:)
    @source = source
  end
end

class InterestTransaction < Transaction
  TYPE = 'interest'

  def initialize(amount:, balance_after:, rate:)
    super(amount:, balance_after:)
    @rate = rate
  end
end

class FeeTransaction < Transaction
  TYPE = 'fee'
end

class TransactionDispatcher
  TRANSACTION_MAP = {
    deposit: DepositTransaction,
    withdraw: WithdrawTransaction,
    transfer_out: TransferOutTransaction,
    transfer_in: TransferInTransaction,
    interest: InterestTransaction,
    fee: FeeTransaction
  }.freeze

  class << self
    def dispatch(type)
      TRANSACTION_MAP[type]
    end
  end
end

class TransactionHistory
  def initialize
    @transactions = []
  end

  def add(transaction)
    @transactions << transaction
  end

  def all
    @transactions
  end

  def to_hashes
    @transactions.map(&:to_h)
  end

  def size
    @transactions.size
  end
end

class AccountBalance
  attr_reader :amount

  def initialize(amount)
    @amount = amount
  end

  def add(amount)
    @amount += amount
  end

  def substract(amount)
    @amount -= amount
  end

  def negative?
    @amount.negative?
  end

  def less_than?(amount)
    @amount < amount
  end
end

class InterestCalculator
  def initialize(interest_rate)
    @interest_rate = interest_rate
  end

  def calculate(balance_amount)
    balance_amount * @interest_rate
  end
end

class BulkTransactionResult
  def initialize
    @successful = 0
    @failed = 0
    @errors = []
  end

  def add_result(result)
    if result.success?
      @successful += 1
    else
      @failed += 1
      @errors << result.error
    end
  end

  def any_successful?
    @successful.positive?
  end

  def summary
    "Bulk transaction completed: #{@successful} successful, #{@failed} failed"
  end

  def to_h
    {
      successful: @successful,
      failed: @failed,
      errors: @errors
    }
  end
end

class TransactionsAggregationCalculator
  CREDIT_TRANSACTION_TYPES = %w[deposit transfer_in interest].freeze
  DEBIT_TRANSACTION_TYPES = %w[withdraw transfer_out fee].freeze

  def initialize(transaction_history)
    @transaction_history = transaction_history
  end

  def calculate
    {
      total_transactions_count:,
      total_deposits:,
      total_withdrawals:
    }
  end

  private

  def credit_transactions
    @transaction_history.all.select { |transaction| CREDIT_TRANSACTION_TYPES.include?(transaction.type) }
  end

  def debit_transactions
    @transaction_history.all.select { |transaction| DEBIT_TRANSACTION_TYPES.include?(transaction.type) }
  end

  def total_transactions_count
    @transaction_history.size
  end

  def total_deposits
    @total_deposits ||= credit_transactions.sum(&:amount)
  end

  def total_withdrawals
    @total_withdrawals ||= debit_transactions.sum(&:amount)
  end
end

class AccountSummary
  def initialize(account_number:, current_balance:, transaction_count:, total_deposits:, total_withdrawals:)
    @account_number = account_number
    @current_balance = current_balance
    @transaction_count = transaction_count
    @total_deposits = total_deposits
    @total_withdrawals = total_withdrawals
  end

  def to_s
    <<~SUMMARY
      Account Number: #{@account_number}
      Current Balance: #{@current_balance}
      Transaction Count: #{@transaction_count}
      Total Deposits: #{@total_deposits}
      Total Withdrawals: #{@total_withdrawals}
    SUMMARY
  end
end

class AccountSummaryGenerator
  def initialize(account_number:, balance_amount:, transaction_history:)
    @account_number = account_number
    @balance_amount = balance_amount
    @transaction_history = transaction_history
  end

  def generate_summary
    aggregation_result = TransactionsAggregationCalculator.new(@transaction_history).calculate

    <<~SUMMARY
      Account Number: #{@account_number}
      Current Balance: #{@balance_amount}
      Transaction Count: #{aggregation_result[:total_transactions_count]}
      Total Deposits: #{aggregation_result[:total_deposits]}
      Total Withdrawals: #{aggregation_result[:total_withdrawals]}
    SUMMARY
  end
end

class BulkTransactionProcessor
  def initialize(account)
    @account = account
  end

  def process(transactions)
    successful, failed = transactions.partition { |transaction_detail| process_single_transaction(transaction_detail) }
    { successful: successful.size, failed: failed.size }
  end

  private

  def process_single_transaction(transaction_detail)
    case transaction_detail[:type]
    when 'deposit'
      @account.deposit(transaction_detail[:amount])
    when 'withdraw'
      @account.withdraw(transaction_detail[:amount])
    when 'fee'
      @account.apply_fee(transaction_detail[:fee] || 0)
    else
      puts "Unknown transaction type: #{transaction_detail[:type]}"
      false
    end
  end
end

class Validator
  private

  def failure_result(info)
    { success: false, info: }
  end
end

class DepositValidator < Validator
  def validate(amount:)
    return failure_result('Invalid amount') if amount <= 0

    { success: true }
  end
end

class WithdrawValidator < Validator
  def validate(amount:, account_balance:)
    return failure_result('Invalid amount') if amount <= 0
    return failure_result('Insufficient funds') if account_balance.less_than?(amount)

    { success: true }
  end
end

class TransferValidator < Validator
  def validate(amount:, account_balance:, target_account:)
    return failure_result('Invalid amount') if amount <= 0
    return failure_result('Insufficient funds') if account_balance.less_than?(amount)
    return failure_result('Target account is nil') if target_account.nil?

    { success: true }
  end
end

class InterestCalculationValidator < Validator
  def validate(rate:)
    return failure_result('Invalid interest rate') if rate.negative? || rate > 1

    { success: true }
  end
end

class FeeApplicationValidator < Validator
  def validate(fee_amount:)
    return failure_result('Fee cannot be negative') if fee_amount.negative?

    { success: true }
  end
end

class BankAccount
  attr_reader :account_number

  def initialize(account_number, initial_balance)
    @account_number = account_number
    @balance = AccountBalance.new(initial_balance)
    @transaction_history = TransactionHistory.new
  end

  def deposit(amount)
    validator = DepositValidator.new
    validation = validator.validate(amount:)

    unless validation[:success]
      puts validation[:info]
      return false
    end

    @balance.add(amount)

    deposit_transaction = TransactionDispatcher.dispatch(:deposit).new(
      amount:,
      balance_after: @balance.amount
    )

    record_transaction(deposit_transaction)

    true
  end

  def withdraw(amount)
    validator = WithdrawValidator.new
    validation = validator.validate(amount:, account_balance: @balance)

    unless validation[:success]
      puts validation[:info]
      return false
    end

    @balance.substract(amount)

    withdraw_transaction = TransactionDispatcher.dispatch(:withdraw).new(
      amount:,
      balance_after: @balance.amount
    )

    record_transaction(withdraw_transaction)

    true
  end

  def transfer(amount, target_account)
    validator = TransferValidator.new
    validation = validator.validate(amount:, account_balance: @balance, target_account:)

    unless validation[:success]
      puts validation[:info]
      return false
    end

    @balance.substract(amount)
    target_account.receive_transfer(amount:, source_account_number: @account_number)

    transfer_out_transaction = TransactionDispatcher.dispatch(:transfer_out).new(
      amount:,
      balance_after: @balance.amount,
      target: target_account.account_number
    )

    record_transaction(transfer_out_transaction)

    true
  end

  def calculate_interest(rate)
    validator = InterestCalculationValidator.new
    validation = validator.validate(rate:)

    unless validation[:success]
      puts validation[:info]
      return nil
    end

    interest = InterestCalculator.new(rate).calculate(@balance.amount)
    @balance.add(interest)

    interest_transaction = TransactionDispatcher.dispatch(:interest).new(
      amount: interest,
      balance_after: @balance.amount,
      rate: rate
    )
    record_transaction(interest_transaction)

    interest
  end

  def get_balance
    @balance.amount
  end

  def get_transaction_history
    @transaction_history.to_hashes
  end

  def apply_fee(fee_amount)
    validator = FeeApplicationValidator.new
    validation = validator.validate(fee_amount:)

    unless validation[:success]
      puts validation[:info]
      return false
    end

    @balance.substract(fee_amount)

    puts 'Warning: Account balance is negative' if @balance.negative?

    fee_transaction = TransactionDispatcher.dispatch(:fee).new(
      amount: fee_amount,
      balance_after: @balance.amount
    )

    record_transaction(fee_transaction)

    true
  end

  def bulk_transactions(transactions)
    result = BulkTransactionProcessor.new(self).process(transactions)

    puts "Bulk transaction completed: #{result[:successful]} successful, #{result[:failed]} failed"

    result
  end

  def account_summary
    summary = AccountSummaryGenerator.new(
      account_number: @account_number,
      balance_amount: @balance.amount,
      transaction_history: @transaction_history
    ).generate_summary

    puts summary
  end

  protected

  def receive_transfer(amount:, source_account_number:)
    @balance.add(amount)

    transfer_in_transaction = TransactionDispatcher.dispatch(:transfer_in).new(
      amount:,
      balance_after: @balance.amount,
      source: source_account_number
    )

    record_transaction(transfer_in_transaction)
  end

  private

  def record_transaction(transaction)
    @transaction_history.add(transaction)
  end
end
