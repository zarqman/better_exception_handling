# Taken from request_exception_handler plugin. See README.

module RequestExceptionHandler

  @@parse_request_parameters_exception_handler = lambda do |request, exception|
    Thread.current[:request_exception] = exception
    logger = defined?(RAILS_DEFAULT_LOGGER) ? RAILS_DEFAULT_LOGGER : Logger.new($stderr)
    logger.info "#{exception.class.name} occurred while parsing request parameters." +
                "\nContents:\n\n#{request.raw_post}"
    { "body" => request.raw_post, "content_type" => request.content_type,
      "content_length" => request.content_length }
  end
  
  mattr_accessor :parse_request_parameters_exception_handler

  def self.reset_request_exception
    Thread.current[:request_exception] = nil
  end

  def self.included(base)
    base.prepend_before_filter :check_request_exception
  end

  def check_request_exception
    e = request_exception
    raise e if e && e.is_a?(Exception)
  end

  def request_exception
    return @_request_exception if @_request_exception
    @_request_exception = Thread.current[:request_exception]
    RequestExceptionHandler.reset_request_exception
    @_request_exception
  end

end



ActionController::ParamsParser.class_eval do

  def parse_formatted_parameters_with_exception_handler(env)
    begin
      out = parse_formatted_parameters_without_exception_handler(env)
      RequestExceptionHandler.reset_request_exception # make sure it's nil
      out
    rescue Exception => e # YAML, XML or Ruby code block errors
      handler = RequestExceptionHandler.parse_request_parameters_exception_handler
      handler ? handler.call(ActionController::Request.new(env), e) : raise
    end
  end

  alias_method_chain :parse_formatted_parameters, :exception_handler

end

