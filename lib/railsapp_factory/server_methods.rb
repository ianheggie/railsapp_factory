require 'tempfile'
require 'fileutils'

class RailsappFactory
  module ServerMethods

    attr_reader :pid
    attr_reader :port

    def stop
      if alive?
        self.logger.info "Stopping server (pid #{pid})"
        Kernel.system "ps -fp #{@pid}" if self.logger.debug?
        Process.kill('INT', @pid) rescue nil
        sleep(1)
        Process.kill('INT', @pid) rescue nil
        20.times do
          sleep(1)
          break unless alive?
        end
        if alive?
          self.logger.info "Gave up waiting (terminating process #{pid} with extreme prejudice)"
          Process.kill('KILL', @pid) rescue nil
        end
        @pid = nil
      end
      if @server_handle
        self.logger.debug 'Closing pipe to server process'
        Timeout.timeout(@timeout) do
          @server_handle.close
        end
        @server_handle = nil
      end
      self.logger.info 'Server has stopped'
    end

    def start
      build unless built?
      # find random unassigned port
      server = TCPServer.new('127.0.0.1', 0)
      @port = server.addr[1]
      server.close
      unless self.logger.debug?
        log_dir = File.join(base_dir, 'logs')
        FileUtils.mkdir_p log_dir
        file = Tempfile.new(['server_', '.log'], log_dir)
        @server_logfile = file.path
        file.close
      end
      self.logger.info "Running Rails #{@version} server on port #{port} #{see_log @server_logfile}"
      exec_arg = defined?(JRUBY_VERSION) ? '' : 'exec'
      in_app { @server_handle = IO.popen("#{exec_arg} /bin/sh -xc 'exec #{server_command} -p #{port}' #{append_log @server_logfile}", 'w') }
      @pid = @server_handle.pid
      # Detach process so alive? will detect if process dies (zombies still accept signals)
      Process.detach(@pid)
      serving_requests = false
      t1 = Time.new
      while true
        raise TimeoutError.new("Waiting for server to be available on the port #{see_log @server_logfile}") if t1 + @timeout < Time.new
        raise RailsappFactory::BuildError.new("Error starting server #{see_log @server_logfile}") unless alive?
        sleep(1)
        begin
          response = Net::HTTP.get(self.uri)
          if response
            t2 = Time.new
            self.logger.info 'Server responded to http GET after %3.1f seconds' % (t2 - t1)
            serving_requests = true
            break
          end
        rescue Errno::ECONNREFUSED
          # do nothing
        rescue Exception => ex
          self.logger.debug "Ignoring exception #{ex} whilst waiting for server to start"
        end
      end
      Kernel.system 'ps -f' if defined?(JRUBY_VERSION) #DEBUG
      serving_requests
    end

  end

end
