class DocumentGenerator
  def generate(type, data)
    if type == 'invoice'
      content = "INVOICE\n"
      content += "================\n\n"
      content += "Invoice Number: #{data[:invoice_number]}\n"
      content += "Date: #{data[:date]}\n"
      content += "Customer: #{data[:customer_name]}\n\n"

      content += "Items:\n"
      total = 0
      for i in 0..data[:items].length - 1
        item = data[:items][i]
        subtotal = item[:quantity] * item[:price]
        content += "  #{item[:name]} x#{item[:quantity]} @ $#{item[:price]} = $#{subtotal}\n"
        total += subtotal
      end

      content += "\nTotal: $#{total}\n"

      return generate_pdf(content) if data[:format] == 'pdf'

      content

    elsif type == 'report'
      content = "REPORT\n"
      content += "================\n\n"
      content += "Title: #{data[:title]}\n"
      content += "Generated: #{Time.now}\n\n"

      content += "Summary:\n"
      content += data[:summary] + "\n\n"

      if data[:sections]
        for i in 0..data[:sections].length - 1
          section = data[:sections][i]
          content += "#{i + 1}. #{section[:heading]}\n"
          content += "#{section[:content]}\n\n"
        end
      end

      return generate_pdf(content) if data[:format] == 'pdf'

      content

    elsif type == 'letter'
      content = ''
      content += "#{data[:sender_address]}\n\n"
      content += "#{data[:date]}\n\n"
      content += "#{data[:recipient_name]}\n"
      content += "#{data[:recipient_address]}\n\n"
      content += "Dear #{data[:recipient_name]},\n\n"
      content += "#{data[:body]}\n\n"
      content += "Sincerely,\n"
      content += "#{data[:sender_name]}\n"

      return generate_pdf(content) if data[:format] == 'pdf'

      content

    elsif type == 'certificate'
      content = "CERTIFICATE OF #{data[:type].upcase}\n"
      content += "================================\n\n"
      content += "This is to certify that\n\n"
      content += "    #{data[:recipient_name]}\n\n"
      content += "#{data[:achievement]}\n\n"
      content += "Date: #{data[:date]}\n"
      content += "Issued by: #{data[:issuer]}\n"

      return generate_pdf(content) if data[:format] == 'pdf'

      content

    else
      'Unknown document type'
    end
  end

  private

  def generate_pdf(content)
    "PDF: #{content}"
  end
end
