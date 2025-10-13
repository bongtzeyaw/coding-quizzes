require 'minitest/autorun'
require_relative 'my_answer'

class BankAccountTest < Minitest::Test
  def setup
    @account = BankAccount.new('123', 100)
    @target = BankAccount.new('456', 50)
  end

  def test_deposit_success
    assert @account.deposit(50)
    assert_equal 150, @account.get_balance
    assert_equal 'deposit', @account.get_transaction_history.last[:type]
  end

  def test_deposit_invalid_amount
    refute @account.deposit(0)
    refute @account.deposit(-10)
    assert_equal 100, @account.get_balance
  end

  def test_withdraw_success
    assert @account.withdraw(50)
    assert_equal 50, @account.get_balance
    assert_equal 'withdraw', @account.get_transaction_history.last[:type]
  end

  def test_withdraw_invalid_amount
    refute @account.withdraw(0)
    refute @account.withdraw(-20)
    assert_equal 100, @account.get_balance
  end

  def test_withdraw_insufficient_funds
    refute @account.withdraw(200)
    assert_equal 100, @account.get_balance
  end

  def test_transfer_success
    assert @account.transfer(50, @target)
    assert_equal 50, @account.get_balance
    assert_equal 100, @target.get_balance
    assert_equal 'transfer_out', @account.get_transaction_history.last[:type]
    assert_equal 'transfer_in', @target.get_transaction_history.last[:type]
  end

  def test_transfer_invalid_amount
    refute @account.transfer(0, @target)
    refute @account.transfer(-10, @target)
    assert_equal 100, @account.get_balance
  end

  def test_transfer_insufficient_funds
    refute @account.transfer(200, @target)
    assert_equal 100, @account.get_balance
  end

  def test_transfer_nil_target
    refute @account.transfer(10, nil)
    assert_equal 100, @account.get_balance
  end

  def test_calculate_interest_success
    interest = @account.calculate_interest(0.1)
    assert_equal 10, interest
    assert_equal 110, @account.get_balance
    assert_equal 'interest', @account.get_transaction_history.last[:type]
  end

  def test_calculate_interest_invalid_rate
    assert_nil @account.calculate_interest(-0.1)
    assert_nil @account.calculate_interest(1.5)
    assert_equal 100, @account.get_balance
  end

  def test_apply_fee_success
    assert @account.apply_fee(20)
    assert_equal 80, @account.get_balance
    assert_equal 'fee', @account.get_transaction_history.last[:type]
  end

  def test_apply_fee_negative
    refute @account.apply_fee(-10)
    assert_equal 100, @account.get_balance
  end

  def test_apply_fee_balance_negative
    assert @account.apply_fee(200)
    assert_equal(-100, @account.get_balance)
  end

  def test_bulk_transactions_success_and_failures
    transactions = [
      { type: 'deposit', amount: 50 },
      { type: 'withdraw', amount: 30 },
      { type: 'withdraw', amount: 500 },
      { type: 'fee', fee: 10 },
      { type: 'unknown', amount: 20 }
    ]
    result = @account.bulk_transactions(transactions)
    assert_equal 3, result[:successful]
    assert_equal 2, result[:failed]
  end

  def test_account_summary_output
    @account.deposit(50)
    @account.withdraw(30)
    @account.apply_fee(10)
    assert_output(/Account Number: 123/) { @account.account_summary }
  end
end
