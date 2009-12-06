module BetterExceptionNotifierHelper
  
  def exclude_raw_post_parameters?
    @controller && @controller.respond_to?(:filter_parameters)
  end
  
  def filter_sensitive_post_data_parameters(parameters)
    exclude_raw_post_parameters? ? @controller.__send__(:filter_parameters, parameters) : parameters
  end
  
  def filter_sensitive_post_data_from_env(env_key, env_value)
    skip_keys = %w(raw_post_data rack.errors rack.input action_controller.rescue.request action_controller.rescue.response rack.request rack.session rack.session.options )
    
    return if skip_keys.include?(env_key.downcase)
    return env_value unless exclude_raw_post_parameters?
    return @controller.__send__(:filter_parameters, {env_key => env_value}).values[0]
  end
  
  # def sanitize_backtrace(trace)
  #   re = Regexp.new(/^#{Regexp.escape(rails_root)}/)
  #   trace.map { |line| Pathname.new(line.gsub(re, "[RAILS_ROOT]")).cleanpath.to_s }
  # end

  def rails_root
    @rails_root ||= Pathname.new(RAILS_ROOT).cleanpath.to_s
  end
  
end
