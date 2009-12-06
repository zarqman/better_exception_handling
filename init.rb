require "action_mailer"
require 'better_exception_notifier'
require 'better_exception_handling'

require 'request_exception_handler'
ActionController::Base.send :include, RequestExceptionHandler
