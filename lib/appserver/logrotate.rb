module Appserver
  class Logrotate < Struct.new(:server_dir)
    include Utils

    def self.write_config (server_dir)
      new(server_dir).write_config
    end

    def initialize (server_dir)
      self.server_dir = server_dir
    end

    def write_config
      safe_replace_file(server_dir.logrotate_conf) do |f|
        f.puts "# Logrotate configuration automagically generated by the \"appserver\" gem using"
        f.puts "# the appserver directory config #{server_dir.config_file}"
        f.puts "# Include this file into your system's logrotate.conf (using an include statement)"
        f.puts "# to use it. See http://github.com/zargony/appserver for details."
        # Handle access logs of Nginx in one statement, so Nginx only needs to reopen once
        access_logs = server_dir.apps.map { |app| app.access_log }.compact
        f.puts "#{access_logs.join(' ')} {"
        f.puts "  missingok"
        f.puts "  delaycompress"
        f.puts "  sharedscripts"
        f.puts "  postrotate"
        f.puts "    #{server_dir.nginx_reopen}"
        f.puts "  endscript"
        f.puts "}"
        # Add application-specific Logrotate configuration
        server_dir.apps.each do |app|
          f.puts ""
          f.puts "# Application: #{app.name}"
          if app.server_log
            f.puts "#{app.server_log} {"
            f.puts "  missingok"
            f.puts "  delaycompress"
            f.puts "  sharedscripts"
            f.puts "  postrotate"
            f.puts "    #{app.reopen_cmd}"
            f.puts "  endscript"
            f.puts "}"
          end
        end
      end
    end
  end
end
