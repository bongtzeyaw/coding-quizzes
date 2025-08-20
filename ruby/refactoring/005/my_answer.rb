# frozen_string_literal: true

class EmailTemplateGeneratorConfig
  attr_reader :config

  def initialize
    @config = {}
  end

  def subject(text)
    @config[:subject] = text
  end

  def body(text)
    @config[:body] = text
  end

  def from(email)
    @config[:from] = email
  end

  def template(file)
    @config[:template] = file
  end
end

class EmailTemplateGenerator
  def initialize(user, config)
    @user = user
    @config = config
  end

  def generate
    {
      to: @user[:email],
      from: @config[:from],
      subject: interpolate_email_template_subject,
      body: interpolate_email_template_body,
      template: @config[:template],
      format: user_format_preference
    }
  end

  private

  def interpolate_email_template_subject
    format(@config[:subject], user_order_id: @user[:order_id])
  end

  def interpolate_email_template_body
    format(@config[:body], user_name: @user[:name])
  end

  def user_format_preference
    @user.dig(:preferences, :html_emails) ? 'html' : 'text'
  end
end

class EmailTemplate
  def initialize(type, user)
    @email_template_generator_configs = {}
    define_templates

    raise ArgumentError, 'Invalid email template type' unless valid_type?(type.to_sym)

    @type = type.to_sym
    @user = user
  end

  def generate
    EmailTemplateGenerator.new(@user, @email_template_generator_configs[@type]).generate
  end

  private

  def define_templates
    template :welcome do
      subject 'Welcome to Our Service!'
      body "Hello %<user_name>s,\n\nThank you for joining us!"
      from 'noreply@example.com'
      template 'welcome.html'
    end

    template :password_reset do
      subject 'Password Reset Request'
      body "Hello %<user_name>s,\n\nClick here to reset your password."
      from 'security@example.com'
      template 'password_reset.html'
    end

    template :order_confirmation do
      subject 'Order Confirmation #%<user_order_id>s'
      body "Hello %<user_name>s,\n\nYour order has been confirmed."
      from 'orders@example.com'
      template 'order.html'
    end

    template :newsletter do
      subject 'Monthly Newsletter'
      body "Hello %<user_name>s,\n\nHere\'s our monthly update."
      from 'newsletter@example.com'
      template 'newsletter.html'
    end
  end

  def valid_type?(type)
    @email_template_generator_configs.key?(type)
  end

  def template(name, &block)
    email_template_generator_config = EmailTemplateGeneratorConfig.new
    email_template_generator_config.instance_eval(&block)
    @email_template_generator_configs[name] = email_template_generator_config.config
  end
end

class EmailNotifier
  def send_email(type, user)
    email = EmailTemplate.new(type, user).generate
    log_successful_email_delivery(email)
    true
  rescue ArgumentError
    log_failed_email_delivery
    false
  end

  private

  def log_successful_email_delivery(email)
    puts "Sending email: #{email}"
  end

  def log_failed_email_delivery
    puts 'Failure sending email'
  end
end
