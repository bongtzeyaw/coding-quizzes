require 'minitest/autorun'
require_relative 'my_answer'

class PaymentProcessorTest < Minitest::Test
  def setup
    @fixed_time = Time.new(2025, 8, 19, 12, 0, 0)
  end

  def test_process_credit_card_success
    Time.stub :now, @fixed_time do
      PaymentProcessor.stub :sleep, nil do
        out, _ = capture_io do
          result = PaymentProcessor.process_credit_card(100, '1234567812345678', '123')
          assert_equal true, result[:success]
          assert_match /^TXN\d+$/, result[:transaction_id]
        end
        assert_includes out, "[#{@fixed_time}] Starting credit card payment processing"
        assert_includes out, "[#{@fixed_time}] Amount: 100"
        assert_includes out, "[#{@fixed_time}] Validation passed"
        assert_includes out, "[#{@fixed_time}] Processing payment..."
        assert_includes out, "[#{@fixed_time}] Payment processed successfully"
        assert_includes out, "[#{@fixed_time}] Transaction ID: TXN"
      end
    end
  end

  def test_process_credit_card_invalid_card_number
    Time.stub :now, @fixed_time do
      out, _ = capture_io do
        result = PaymentProcessor.process_credit_card(100, '1234', '123')
        assert_equal false, result[:success]
        assert_equal 'Invalid card number', result[:error]
      end
      assert_includes out, "[#{@fixed_time}] Starting credit card payment processing"
      assert_includes out, "[#{@fixed_time}] Amount: 100"
      assert_includes out, "[#{@fixed_time}] ERROR: Invalid card number"
    end
  end

  def test_process_credit_card_invalid_cvv
    Time.stub :now, @fixed_time do
      out, _ = capture_io do
        result = PaymentProcessor.process_credit_card(100, '1234567812345678', '12')
        assert_equal false, result[:success]
        assert_equal 'Invalid CVV', result[:error]
      end
      assert_includes out, "[#{@fixed_time}] Starting credit card payment processing"
      assert_includes out, "[#{@fixed_time}] Amount: 100"
      assert_includes out, "[#{@fixed_time}] ERROR: Invalid CVV"
    end
  end

  def test_process_credit_card_invalid_amount
    Time.stub :now, @fixed_time do
      out, _ = capture_io do
        result = PaymentProcessor.process_credit_card(0, '1234567812345678', '123')
        assert_equal false, result[:success]
        assert_equal 'Invalid amount', result[:error]
      end
      assert_includes out, "[#{@fixed_time}] Starting credit card payment processing"
      assert_includes out, "[#{@fixed_time}] Amount: 0"
      assert_includes out, "[#{@fixed_time}] ERROR: Invalid amount"
    end
  end

  def test_process_bank_transfer_success
    Time.stub :now, @fixed_time do
      PaymentProcessor.stub :sleep, nil do
        out, _ = capture_io do
          result = PaymentProcessor.process_bank_transfer(200, '12345678', '987654321')
          assert_equal true, result[:success]
          assert_match /^BNK\d+$/, result[:transaction_id]
        end
        assert_includes out, "[#{@fixed_time}] Starting bank transfer processing"
        assert_includes out, "[#{@fixed_time}] Amount: 200"
        assert_includes out, "[#{@fixed_time}] Validation passed"
        assert_includes out, "[#{@fixed_time}] Processing transfer..."
        assert_includes out, "[#{@fixed_time}] Transfer processed successfully"
        assert_includes out, "[#{@fixed_time}] Transaction ID: BNK"
      end
    end
  end

  def test_process_bank_transfer_invalid_account_number
    Time.stub :now, @fixed_time do
      out, _ = capture_io do
        result = PaymentProcessor.process_bank_transfer(200, '123', '987654321')
        assert_equal false, result[:success]
        assert_equal 'Invalid account number', result[:error]
      end
      assert_includes out, "[#{@fixed_time}] Starting bank transfer processing"
      assert_includes out, "[#{@fixed_time}] Amount: 200"
      assert_includes out, "[#{@fixed_time}] ERROR: Invalid account number"
    end
  end

  def test_process_bank_transfer_invalid_routing_number
    Time.stub :now, @fixed_time do
      out, _ = capture_io do
        result = PaymentProcessor.process_bank_transfer(200, '12345678', '123')
        assert_equal false, result[:success]
        assert_equal 'Invalid routing number', result[:error]
      end
      assert_includes out, "[#{@fixed_time}] Starting bank transfer processing"
      assert_includes out, "[#{@fixed_time}] Amount: 200"
      assert_includes out, "[#{@fixed_time}] ERROR: Invalid routing number"
    end
  end

  def test_process_bank_transfer_invalid_amount
    Time.stub :now, @fixed_time do
      out, _ = capture_io do
        result = PaymentProcessor.process_bank_transfer(0, '12345678', '987654321')
        assert_equal false, result[:success]
        assert_equal 'Invalid amount', result[:error]
      end
      assert_includes out, "[#{@fixed_time}] Starting bank transfer processing"
      assert_includes out, "[#{@fixed_time}] Amount: 0"
      assert_includes out, "[#{@fixed_time}] ERROR: Invalid amount"
    end
  end
end
