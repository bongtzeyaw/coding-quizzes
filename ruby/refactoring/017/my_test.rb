# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'my_answer'

class DocumentGeneratorTest < Minitest::Test
  def setup
    @generator = DocumentGenerator.new
  end

  def test_generate_invoice_text
    data = {
      invoice_number: 'INV123',
      date: '2025-09-11',
      customer_name: 'John Doe',
      items: [
        { name: 'Apple', quantity: 2, price: 3 },
        { name: 'Banana', quantity: 1, price: 1 }
      ],
      format: 'text'
    }
    expected = <<~DOC
      INVOICE
      ================

      Invoice Number: INV123
      Date: 2025-09-11
      Customer: John Doe

      Items:
        Apple x2 @ $3 = $6
        Banana x1 @ $1 = $1

      Total: $7
    DOC
    assert_equal expected, @generator.generate('invoice', data)
  end

  def test_generate_invoice_pdf
    data = {
      invoice_number: 'INV456',
      date: '2025-09-11',
      customer_name: 'Alice',
      items: [{ name: 'Pen', quantity: 5, price: 2 }],
      format: 'pdf'
    }
    expected = <<~DOC
      PDF: INVOICE
      ================

      Invoice Number: INV456
      Date: 2025-09-11
      Customer: Alice

      Items:
        Pen x5 @ $2 = $10

      Total: $10
    DOC
    assert_equal expected, @generator.generate('invoice', data)
  end

  def test_generate_report_text_with_sections
    Time.stub :now, Time.new(2025, 9, 11, 12, 0, 0) do
      data = {
        title: 'Monthly Report',
        summary: 'This is the summary.',
        sections: [
          { heading: 'Introduction', content: 'Intro content' },
          { heading: 'Details', content: 'Details content' }
        ],
        format: 'text'
      }
      expected = <<~DOC
        REPORT
        ================

        Title: Monthly Report
        Generated: 2025-09-11 12:00:00 +0900

        Summary:
        This is the summary.

        1. Introduction
        Intro content

        2. Details
        Details content

      DOC
      assert_equal expected, @generator.generate('report', data)
    end
  end

  def test_generate_report_pdf_without_sections
    Time.stub :now, Time.new(2025, 9, 11, 15, 30, 0) do
      data = {
        title: 'Weekly Report',
        summary: 'Summary only',
        format: 'pdf'
      }
      expected = <<~DOC
        PDF: REPORT
        ================

        Title: Weekly Report
        Generated: 2025-09-11 15:30:00 +0900

        Summary:
        Summary only

      DOC
      assert_equal expected, @generator.generate('report', data)
    end
  end

  def test_generate_letter_text
    data = {
      sender_address: '123 Street',
      date: '2025-09-11',
      recipient_name: 'Bob',
      recipient_address: '456 Avenue',
      body: 'This is the body.',
      sender_name: 'Alice',
      format: 'text'
    }
    expected = <<~DOC
      123 Street

      2025-09-11

      Bob
      456 Avenue

      Dear Bob,

      This is the body.

      Sincerely,
      Alice
    DOC
    assert_equal expected, @generator.generate('letter', data)
  end

  def test_generate_letter_pdf
    data = {
      sender_address: 'XYZ Road',
      date: '2025-09-11',
      recipient_name: 'Charlie',
      recipient_address: '789 Lane',
      body: 'Letter content',
      sender_name: 'Dana',
      format: 'pdf'
    }
    expected = <<~DOC
      PDF: XYZ Road

      2025-09-11

      Charlie
      789 Lane

      Dear Charlie,

      Letter content

      Sincerely,
      Dana
    DOC
    assert_equal expected, @generator.generate('letter', data)
  end

  def test_generate_certificate_text
    data = {
      type: 'completion',
      recipient_name: 'Eve',
      achievement: 'Completed Ruby Course',
      date: '2025-09-11',
      issuer: 'Ruby Academy',
      format: 'text'
    }
    expected = <<~DOC
      CERTIFICATE OF COMPLETION
      ================================

      This is to certify that

          Eve

      Completed Ruby Course

      Date: 2025-09-11
      Issued by: Ruby Academy
    DOC
    assert_equal expected, @generator.generate('certificate', data)
  end

  def test_generate_certificate_pdf
    data = {
      type: 'excellence',
      recipient_name: 'Frank',
      achievement: 'Top Performer',
      date: '2025-09-11',
      issuer: 'Company',
      format: 'pdf'
    }
    expected = <<~DOC
      PDF: CERTIFICATE OF EXCELLENCE
      ================================

      This is to certify that

          Frank

      Top Performer

      Date: 2025-09-11
      Issued by: Company
    DOC
    assert_equal expected, @generator.generate('certificate', data)
  end

  def test_generate_unknown_type
    assert_equal 'Unknown document type', @generator.generate('unknown', {})
  end
end
