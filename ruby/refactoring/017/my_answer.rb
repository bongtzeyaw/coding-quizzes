# frozen_string_literal: true

class Document
  def initialize(data)
    @data = data
  end

  def generate
    raise NotImplementedError, "#{self.class} must implement #generate"
  end
end

class Invoice < Document
  TEMPLATE = <<~DOC
    INVOICE
    ================

    Invoice Number: %<invoice_number>s
    Date: %<date>s
    Customer: %<customer_name>s

    Items:
    %<item_details_text>s

    %<total_text>s
  DOC

  def generate
    format(TEMPLATE,
           invoice_number: @data[:invoice_number],
           date: @data[:date],
           customer_name: @data[:customer_name],
           item_details_text: item_details_text(@data[:items]),
           total_text: total_text(@data[:items]))
  end

  private

  def item_details_text(items)
    items.map do |item|
      subtotal = item[:quantity] * item[:price]
      "  #{item[:name]} x#{item[:quantity]} @ $#{item[:price]} = $#{subtotal}"
    end.join("\n")
  end

  def total_text(items)
    total = items.sum { |item| item[:quantity] * item[:price] }
    "Total: $#{total}"
  end
end

class Report < Document
  TEMPLATE = <<~DOC
    REPORT
    ================

    Title: %<title>s
    Generated: %<generated>s

    Summary:
    %<summary>s
    %<sections_text>s
  DOC

  def generate
    format(TEMPLATE,
           title: @data[:title],
           generated: Time.now,
           summary: @data[:summary],
           sections_text: sections_text(@data[:sections]))
  end

  private

  def sections_text(sections)
    return '' unless sections

    sections.each_with_index.map do |section, i|
      "#{i + 1}. #{section[:heading]}\n#{section[:content]}\n"
    end.join("\n").prepend("\n")
  end
end

class Letter < Document
  TEMPLATE = <<~DOC
    %<sender_address>s

    %<date>s

    %<recipient_name>s
    %<recipient_address>s

    Dear %<recipient_name>s,

    %<body>s

    Sincerely,
    %<sender_name>s
  DOC

  def generate
    format(TEMPLATE,
           sender_address: @data[:sender_address],
           date: @data[:date],
           recipient_name: @data[:recipient_name],
           recipient_address: @data[:recipient_address],
           body: @data[:body],
           sender_name: @data[:sender_name])
  end
end

class Certificate < Document
  TEMPLATE = <<~DOC
    CERTIFICATE OF %<type>s
    ================================

    This is to certify that

        %<recipient_name>s

    %<achievement>s

    Date: %<date>s
    Issued by: %<issuer>s
  DOC

  def generate
    format(TEMPLATE,
           type: @data[:type].upcase,
           recipient_name: @data[:recipient_name],
           achievement: @data[:achievement],
           date: @data[:date],
           issuer: @data[:issuer])
  end
end

class DocumentFactory
  DOCUMENT_TYPE_MAP = {
    invoice: Invoice,
    report: Report,
    letter: Letter,
    certificate: Certificate
  }.freeze

  def self.create(type)
    DOCUMENT_TYPE_MAP[type.to_sym]
  end
end

class DocumentGenerator
  def generate(type, data)
    document_class = DocumentFactory.create(type)
    return 'Unknown document type' unless document_class

    content = document_class.new(data).generate

    return generate_pdf(content) if data[:format] == 'pdf'

    content
  end

  private

  def generate_pdf(content)
    "PDF: #{content}"
  end
end
