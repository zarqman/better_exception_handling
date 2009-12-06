class BetterExceptionNotifier < ActionMailer::Base
  @@sender_address = 'app.error@myapp.com'
  cattr_accessor :sender_address
  
  @@exception_recipients = []
  cattr_accessor :exception_recipients
  
  @@email_prefix = '[ERROR] '
  cattr_accessor :email_prefix
  
  
  self.template_root = "#{File.dirname(__FILE__)}/../app/views"
  
  
  def exception_notification(exception, controller, request, backtrace)
    content_type "text/plain"

    subject    "#{email_prefix}#{controller.class}##{controller.action_name} (#{exception.class}) #{exception.message.inspect}"

    recipients exception_recipients
    from       sender_address

    body       :controller => controller, :request => request, :exception => exception, :backtrace => backtrace
                  
  end
  
end