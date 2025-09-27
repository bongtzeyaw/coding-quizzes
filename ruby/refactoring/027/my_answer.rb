class BankAccount
  def initialize(account_number, initial_balance)
    @account_number = account_number
    @balance = initial_balance
    @transaction_history = []
  end

  def deposit(amount)
    if amount <= 0
      puts 'Invalid amount'
      return false
    end

    @balance += amount
    @transaction_history << {
      type: 'deposit',
      amount: amount,
      timestamp: Time.now,
      balance_after: @balance
    }

    true
  end

  def withdraw(amount)
    if amount <= 0
      puts 'Invalid amount'
      return false
    end

    if amount > @balance
      puts 'Insufficient funds'
      return false
    end

    @balance -= amount
    @transaction_history << {
      type: 'withdraw',
      amount: amount,
      timestamp: Time.now,
      balance_after: @balance
    }

    true
  end

  def transfer(amount, target_account)
    if amount <= 0
      puts 'Invalid amount'
      return false
    end

    if amount > @balance
      puts 'Insufficient funds'
      return false
    end

    if target_account.nil?
      puts 'Target account is nil'
      return false
    end

    @balance -= amount
    target_account.instance_variable_set(:@balance, target_account.instance_variable_get(:@balance) + amount)

    @transaction_history << {
      type: 'transfer_out',
      amount: amount,
      target: target_account.instance_variable_get(:@account_number),
      timestamp: Time.now,
      balance_after: @balance
    }

    target_account.instance_variable_get(:@transaction_history) << {
      type: 'transfer_in',
      amount: amount,
      source: @account_number,
      timestamp: Time.now,
      balance_after: target_account.instance_variable_get(:@balance)
    }

    true
  end

  def calculate_interest(rate)
    if rate < 0 || rate > 1
      puts 'Invalid interest rate'
      return nil
    end

    interest = @balance * rate
    @balance += interest

    @transaction_history << {
      type: 'interest',
      amount: interest,
      rate: rate,
      timestamp: Time.now,
      balance_after: @balance
    }

    interest
  end

  def get_balance
    @balance
  end

  def get_transaction_history
    @transaction_history
  end

  def apply_fee(fee_amount)
    if fee_amount < 0
      puts 'Fee cannot be negative'
      return false
    end

    @balance -= fee_amount

    puts 'Warning: Account balance is negative' if @balance < 0

    @transaction_history << {
      type: 'fee',
      amount: fee_amount,
      timestamp: Time.now,
      balance_after: @balance
    }

    true
  end

  def bulk_transactions(transactions)
    successful = 0
    failed = 0

    transactions.each do |transaction|
      type = transaction[:type]
      amount = transaction[:amount]

      case type
      when 'deposit'
        if deposit(amount)
          successful += 1
        else
          failed += 1
        end
      when 'withdraw'
        if withdraw(amount)
          successful += 1
        else
          failed += 1
        end
      when 'fee'
        fee = transaction[:fee] || 0
        if apply_fee(fee)
          successful += 1
        else
          failed += 1
        end
      else
        puts "Unknown transaction type: #{type}"
        failed += 1
      end
    end

    puts "Bulk transaction completed: #{successful} successful, #{failed} failed"
    { successful: successful, failed: failed }
  end

  def account_summary
    puts "Account Number: #{@account_number}"
    puts "Current Balance: #{@balance}"
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
end
