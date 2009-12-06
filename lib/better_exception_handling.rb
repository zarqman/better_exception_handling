module BetterExceptionHandling
  module ClassMethods
    
    # By default, will render the Rails standard HTML response for all
    # Content-type's. Content-type specific exception rendering methods are
    # provided for XML, YAML, JSON, and JS (text). They can be individually
    # enabled using:
    #
    #   enable_content_specific_exceptions :xml, :yaml, :json, :js
    #
    # Alternatively, you may define your own custom exception rendering by 
    # defining any or or all of the custom methods:
    #
    #   rescue_action_locally_html(exception)
    #   rescue_action_locally_xml(exception)
    #   rescue_action_locally_yaml(exception)
    #   rescue_action_locally_json(exception)
    #   rescue_action_locally_js(exception)
    # 
    def enable_content_specific_exceptions(*types)
      types.each do |type|
        case type.to_sym
        when :xml
          class_eval { alias :rescue_action_locally_xml  :render_backtrace_for_xml }
        when :yaml
          class_eval { alias :rescue_action_locally_yaml :render_backtrace_for_yaml }
        when :json
          class_eval { alias :rescue_action_locally_json :render_backtrace_for_json }
        when :js
          class_eval { alias :rescue_action_locally_js   :render_backtrace_for_js }
        # when :html
        #   class_eval { alias :rescue_action_locally_html :render_backtrace_for_html }
        else
          raise ArgumentError, "Unknown type #{type} passed to enable_content_specific_exceptions()"
        end
      end
    end
    
  end
  
  
  protected
  
  
  # Override this method to customize the page or message returned for HTML page loads.
  def render_auth_token_error_html
    msg = "Error: Unable to verify the authenticity of your session. This can happen if cookies are disabled or overly restricted. Please check your cookies, reload the page, and try again."
    render :text=>msg, :status=>:bad_request
  end
  
  # Override this method to customize the page or message returned for XHR (AJAX) page loads.
  def render_auth_token_error_js
    msg = "Error: Unable to verify the authenticity of your session. This can happen if cookies are disabled or overly restricted. Please check your cookies, reload the page, and try again."
    render :text=>msg, :status=>:bad_request
  end
  
  
  
  # Ensure content-type is application/xml for POST and PUT requests. 
  # Rails fails to parse XML sent as application/x-www-form-urlencoded
  # (which is proper) but delivers a non-helpful 500 error. Since this is
  # a client error and not a server error, this should be a 4xx series
  # error instead.
  #
  # Use as a before_filter on relevant controllers (or an entire app):
  # 
  #   before_filter :validate_content_type_for_xml
  #
  # This really shouldn't be enabled application wide if the app is more
  # than just an API server. The key test is are there any key names in
  # the params hash that have < or > in them. This is a very basic test,
  # although surprisingly effective. Regardless, it is recommended to 
  # include this module only for controllers or actions where you know 
  # this test is safe and won't overreach.
  #
  # Note also that Rails 2.3.2 and prior (and maybe 2.3.3) will also puke
  # when the Content-type: application/xml header is present on a GET or
  # DELETE request. Unfortunately, this error happens way up the stack and
  # cannot be caught here. Rails 2.3.4 appears to fix this.
  #
  def validate_content_type_for_xml
    if request.post? or request.put?
      # Already proper content-type, so we're okay
      return if request.content_type =~ Mime::XML 
      
      # Test for mis-parsed XML content presented as 
      #   application/x-www-form-urlencoded -- this usually manifests 
      #   itself with a key name containing < or >
      return unless params.keys.detect{|k| k =~ /[<>]/}

      # It's hard to decide what the best choice is for rendering the 
      # error. As the data and content-type are already mismatched, we'll
      # just deliver a text error.
      msg = "415 Unsupported media type\n\nFor all PUT and POST requests with XML payloads, ensure you have a 'Content-Type: application/xml' header.\n"
      render :text=>msg, :status=>:unsupported_media_type
    end
  end
  
  
  
  
  # Override default Rails exception logging to include sending an email
  def log_error(exception)
    super
    
    # don't email for local requests
    return if local_request?
    
    status_code = response_code_for_rescue(exception)
    status = ActionController::StatusCodes::SYMBOL_TO_STATUS_CODE[status_code] || 500
    if (500...600).include? status
      BetterExceptionNotifier.deliver_exception_notification(exception, self, request, clean_backtrace(exception))
    end
  end
  
  
  
  # Override default Rails public exception handler to first check for a local
  # view template. The template should be named with the status code 
  # (generally 500) along with the content-type and template engine. Examples:
  #
  #   views/exceptions/500.html.erb
  #   views/exceptions/500.js.rjs
  #   views/exceptions/500.json.erb
  #   views/exceptions/500.xml.builder
  #
  # Note that this allows for content-type specific errors. The instance 
  # variable @status is made available to the template and will look something
  # like "500 Internal Server Error".
  #
  # In the event a matching template cannot be found, a content-type suitable
  # default will be used. These are super simple, for example the XML error:
  #
  #   <error>500 Internal Server Error</error>
  #
  def rescue_action_in_public(exception)
    status_code = response_code_for_rescue(exception)
    status = interpret_status(status_code)
    
    @status = status
    respond_to do |type|
      type.html { render_error_for_html(exception, status) }
      type.xml  { render_error_for_xml(exception, status)  }
      type.yaml { render_error_for_yaml(exception, status) }
      type.json { render_error_for_json(exception, status) }
      type.js   { render_error_for_js(exception, status)   }
    end
    
  rescue ActionView::MissingTemplate
    respond_to do |type|
      type.html { render_optional_error_file(status_code) }
      type.xml  { render :xml=>Builder::XmlMarkup.new.error(status), :status=>status }
      type.yaml { render :json=>{:error=>status}, :status=>status, :content_type=>Mime::YAML }
      type.json { render :json=>{:error=>status}, :status=>status }
      type.js   { render :text=>status, :status=>status }
    end
  end
  
  def render_error_for_html(exception, status) #:nodoc:
    render "exceptions/#{status[0,3]}.html", :status=>status, :layout=>false
  end
  def render_error_for_xml(exception, status) #:nodoc:
    render "exceptions/#{status[0,3]}.xml", :status=>status, :layout=>false
  end
  def render_error_for_yaml(exception, status) #:nodoc:
    render "exceptions/#{status[0,3]}.yaml", :status=>status, :layout=>false
  end
  def render_error_for_json(exception, status) #:nodoc:
    render "exceptions/#{status[0,3]}.json", :status=>status, :layout=>false
  end
  def render_error_for_js(exception, status) #:nodoc:
    render "exceptions/#{status[0,3]}.js", :status=>status, :layout=>false
  end
    
  
  
  # See comments for enable_content_specific_exceptions()
  def rescue_action_locally_better(exception) #:nodoc:
    respond_to do |type|
      type.html { 
        respond_to?(:rescue_action_locally_html) ? rescue_action_locally_html(exception) : render_backtrace_for_html(exception)
      }
      type.xml  { 
        respond_to?(:rescue_action_locally_xml)  ? rescue_action_locally_xml(exception)  : render_backtrace_for_html(exception)
      }
      type.yaml { 
        respond_to?(:rescue_action_locally_yaml) ? rescue_action_locally_yaml(exception) : render_backtrace_for_html(exception)
      }
      type.json { 
        respond_to?(:rescue_action_locally_json) ? rescue_action_locally_json(exception) : render_backtrace_for_html(exception)
      }
      type.js   { 
        respond_to?(:rescue_action_locally_js)   ? rescue_action_locally_js(exception)   : render_backtrace_for_html(exception)
      }
    end
  end
  
  def render_backtrace_for_xml(exception) #:nodoc:
    status_code = response_code_for_rescue(exception)
    xml = Builder::XmlMarkup.new.exception do |e|
      e.class exception.class
      e.action "#{self.class}##{action_name}"
      e.message exception.message
      # e.backtrace exception.backtrace.join("\n")
      e.backtrace do |b|
        exception.backtrace.each do |step|
          b.step step
        end
      end
      e.request_parameters params.inspect
    end
    render :xml=>xml, :status=>status_code
  end

  def render_backtrace_for_yaml(exception) #:nodoc:
    render_backtrace_for_json(exception, Mime::YAML)
  end
  
  def render_backtrace_for_json(exception, mime=Mime::JSON) #:nodoc:
    status_code = response_code_for_rescue(exception)
    j = {:exception=>{:class=>exception.class.to_s, :action=>"#{self.class}##{action_name}", :message=>exception.message,
           :backtrace=>exception.backtrace, :request_parameters=>params}}
    render :json=>j, :status=>status_code, :content_type=>mime
    # firefox (and maybe others) won't render Content-type: application/json ... 
    #   to workaround, change :content_type to Mime::TEXT
  end
  
  def render_backtrace_for_js(exception) #:nodoc:
    status_code = response_code_for_rescue(exception)
    o =  "#{exception.class} in #{self.class}##{action_name}\n"
    o << "#{exception.message}\n\n"
    o << "Backtrace:\n  #{exception.backtrace.join("\n  ")}\n\n"
    o << "Request parameters:\n  #{params.inspect}\n"
    render :text=>o, :status=>status_code
  end 
  
  
  
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    
    receiver.class_eval do
      alias :render_backtrace_for_html :rescue_action_locally
      alias :rescue_action_locally :rescue_action_locally_better
      
      
      # Handle XML parsing errors with a helpful error message.
      rescue_from 'LibXML::XML::Error', 'REXML::ParseException' do |exception|
        render :xml=>Builder::XmlMarkup.new.error('Parsing Error'), :status=>:bad_request # :unprocessable_entity
      end

      #todo: need to handle other XML and JSON/YAML engines
      
      rescue_from 'ActiveSupport::JSON::ParseError' do |exception|
        render :json=>{:error=>"Parsing Error"}, :status=>:bad_request
      end
      
      
      # Handle invalid authenticity errors with helpful error messages.
      rescue_from 'ActionController::InvalidAuthenticityToken' do |exception|
        logger.error "ERROR: Invalid Authenticity Token !!!"
        respond_to do |type|
          type.html { render_auth_token_error_html }
          type.js   { render_auth_token_error_js   }
        end
      end
      
    end
  end
  
end