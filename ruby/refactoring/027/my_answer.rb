# frozen_string_literal: true

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

class BankAccount
  attr_reader :account_number

  def initialize(account_number, initial_balance)
    @account_number = account_number
    @balance = AccountBalance.new(initial_balance)
    @transaction_history = TransactionHistory.new
  end

  def deposit(amount)
    if amount <= 0
      puts 'Invalid amount'
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
    if amount <= 0
      puts 'Invalid amount'
      return false
    end

    if @balance.less_than?(amount)
      puts 'Insufficient funds'
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
    if amount <= 0
      puts 'Invalid amount'
      return false
    end

    if @balance.less_than?(amount)
      puts 'Insufficient funds'
      return false
    end

    if target_account.nil?
      puts 'Target account is nil'
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
    if rate < 0 || rate > 1
      puts 'Invalid interest rate'
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
    if fee_amount < 0
      puts 'Fee cannot be negative'
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
    puts "Account Number: #{@account_number}"
    puts "Current Balance: #{@balance.amount}"
    puts "Transaction Count: #{@transaction_history.length}"

    total_deposits = 0
    total_withdrawals = 0

    @transaction_history.each do |transaction|
      case transaction[:type]
      when 'deposit', 'transfer_in', 'interest'
        total_deposits += transaction[:amount]
      when 'withdraw', 'transfer_out', 'fee'
        total_withdrawals += transaction[:amount]
      end
    end

    puts "Total Deposits: #{total_deposits}"
    puts "Total Withdrawals: #{total_withdrawals}"
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
