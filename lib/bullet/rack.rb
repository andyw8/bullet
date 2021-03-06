module Bullet
  class Rack
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless Bullet.enable?

      Bullet.start_request
      status, headers, response = @app.call(env)
      return [status, headers, response] if file?(headers) || empty?(response)

      response_body = nil
      if Bullet.notification?
        if status == 200 && !response.body.frozen? && html_request?(headers, response)
          response_body = response.body << Bullet.gather_inline_notifications
          headers['Content-Length'] = response_body.bytesize.to_s
        end
        Bullet.perform_out_of_channel_notifications(env)
      end
      Bullet.end_request
      [status, headers, response_body ? [response_body] : response]
    end

    # fix issue if response's body is a Proc
    def empty?(response)
      # response may be ["Not Found"], ["Move Permanently"], etc.
      (response.is_a?(Array) && response.size <= 1) ||
        !response.respond_to?(:body) ||
        !response.body.respond_to?(:empty?) ||
        response.body.empty?
    end

    # if send file?
    def file?(headers)
      headers["Content-Transfer-Encoding"] == "binary"
    end

    def html_request?(headers, response)
      headers['Content-Type'] && headers['Content-Type'].include?('text/html') && response.body.include?("<html")
    end
  end
end
