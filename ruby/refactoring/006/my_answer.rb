class PaymentProcessor
  def process_credit_card(amount, card_number, cvv)
    puts "[#{Time.now}] Starting credit card payment processing"
    puts "[#{Time.now}] Amount: #{amount}"

    if card_number.length != 16
      puts "[#{Time.now}] ERROR: Invalid card number length"
      return { success: false, error: 'Invalid card number' }
    end

    if cvv.length != 3
      puts "[#{Time.now}] ERROR: Invalid CVV"
      return { success: false, error: 'Invalid CVV' }
    end

    if amount <= 0
      puts "[#{Time.now}] ERROR: Invalid amount"
      return { success: false, error: 'Invalid amount' }
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

    if account_number.length < 8 || account_number.length > 12
      puts "[#{Time.now}] ERROR: Invalid account number"
      return { success: false, error: 'Invalid account number' }
    end

    if routing_number.length != 9
      puts "[#{Time.now}] ERROR: Invalid routing number"
      return { success: false, error: 'Invalid routing number' }
    end

    if amount <= 0
      puts "[#{Time.now}] ERROR: Invalid amount"
      return { success: false, error: 'Invalid amount' }
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
