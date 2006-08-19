class ActionController::CgiResponse
  # on windows it is sometimes necessary to turn off writing output
  # to avoid out of memory errors running under the console
  def out(output = $stdout)
    convert_content_type!(@headers)
    output.binmode      if output.respond_to?(:binmode)
    output.sync = false if output.respond_to?(:sync=)
    begin
      output.write(@cgi.header(@headers))
      output.flush if output.respond_to?(:flush)
    rescue Errno::EPIPE => e
      # lost connection to the FCGI process -- ignore the output, then
    end
  end
end
