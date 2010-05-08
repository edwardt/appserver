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
        # Handle logs of apps with minimal statements, to minimize reopen calls
        reopen_cmds = server_dir.apps.inject({}) do |memo, app|
          app.log_reopen_cmds.each do |logfile, reopen_cmd|
            memo[reopen_cmd] ||= []
            memo[reopen_cmd] << logfile
          end
          memo
        end
        reopen_cmds.each do |reopen_cmd, logfiles|
          f.puts "#{logfiles.join(' ')} {"
          f.puts "  missingok"
          f.puts "  delaycompress"
          f.puts "  sharedscripts"
          f.puts "  postrotate"
          f.puts "    #{reopen_cmd}"
          f.puts "  endscript"
          f.puts "}"
        end
      end
    end
  end
end
