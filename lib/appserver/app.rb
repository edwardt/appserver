module Appserver
  class App < Struct.new(:unicorn, :environment, :instances, :pids_dir, :sockets_dir, :server_log, :max_cpu_usage,
                         :max_memory_usage, :usage_check_cycles, :http_check_timeout, :hostname, :access_log,
                         :public_dir)
    DEFAULTS = {
      :unicorn => '/usr/local/bin/unicorn',
      :environment => 'production',
      :instances => 3,
      :pids_dir => 'tmp/pids',
      :sockets_dir => 'tmp/sockets',
      :server_log => 'log/server.log',
      :max_cpu_usage => nil,
      :max_memory_usage => nil,
      :usage_check_cycles => 5,
      :http_check_timeout => 30,
      :hostname => `/bin/hostname -f`.chomp.gsub(/^[^.]+\./, ''),
      :access_log => 'log/access.log',
      :public_dir => 'public',
    }

    attr_reader :server, :name

    def initialize (server, name, settings = {})
      super()
      @server, @name = server, name
      appsettings = (settings[:apps] || {})[name.to_sym] || {}
      members.each do |key|
        self[key] = appsettings[key] || settings[key] || DEFAULTS[key]
      end
      # Use a subdomain of the default hostname if no hostname was given specifically for this app
      self.hostname = "#{name}.#{hostname}" unless appsettings[:hostname]
    end

    def dir
      File.join(server.dir, name)
    end

    def rack_config
      File.join(dir, 'config.ru')
    end

    def rack?
      File.exist?(rack_config)
    end

    def unicorn_config
      File.expand_path('../unicorn.conf.rb', __FILE__)
    end

    def pidfile
      File.join(pids_dir, 'unicorn.pid')
    end

    def socket
      File.join(sockets_dir, 'unicorn.socket')
    end

    def write_monit_config (f)
      f.puts %Q()
      f.puts %Q(# Application: #{name})
      if rack?
        cyclecheck = usage_check_cycles > 1 ? " for #{usage_check_cycles} cycles" : ''
        f.puts %Q(check process #{name} with pidfile #{expand_path(pidfile)})
        f.puts %Q(  start program = "#{unicorn} -E #{environment} -Dc #{unicorn_config} #{rack_config}")
        f.puts %Q(  stop program = "/bin/kill `cat #{expand_path(pidfile)}`")
        f.puts %Q(  if totalcpu usage > #{max_cpu_usage}#{cyclecheck} then restart) if max_cpu_usage
        f.puts %Q(  if totalmemory usage > #{max_memory_usage}#{cyclecheck} then restart) if max_memory_usage
        f.puts %Q(  if failed unixsocket #{expand_path(socket)} protocol http request "/" timeout #{http_check_timeout} seconds then restart) if http_check_timeout > 0
        f.puts %Q(  if 5 restarts within 5 cycles then timeout)
        f.puts %Q(  group #{name})
      end
    end

    def write_nginx_config (f)
      f.puts ""
      f.puts "# Application: #{name}"
      if rack?
        f.puts "upstream #{name}_cluster {"
        f.puts "  server unix:#{expand_path(socket)} fail_timeout=0;"
        f.puts "}"
        f.puts "server {"
        f.puts "  listen 80;"
        f.puts "  server_name #{hostname};"
        f.puts "  root #{expand_path(public_dir)};"
        f.puts "  access_log #{expand_path(access_log)};"
        f.puts "  location / {"
        f.puts "    proxy_set_header X-Real-IP $remote_addr;"
        f.puts "    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
        f.puts "    proxy_set_header Host $http_host;"
        f.puts "    proxy_redirect off;"
        # TODO: maintenance mode rewriting
        f.puts "    try_files $uri/index.html $uri.html $uri @#{name}_cluster;"
        f.puts "    error_page 500 502 503 504 /500.html;"
        f.puts "  }"
        f.puts "  location @#{name}_cluster {"
        f.puts "    proxy_pass http://#{name}_cluster;"
        f.puts "  }"
        f.puts "}"
      end
    end

  protected

    def expand_path (path)
      File.expand_path(path, dir)
    end
  end
end
