require 'etc'
require 'yaml'

module Appserver
  class Server < Struct.new(:dir, :repo_dir, :monit_conf, :monit_reload, :nginx_conf, :nginx_reload, :logrotate_conf)
    class AlreadyInitializedError < RuntimeError; end
    class DirectoryNotEmptyError < RuntimeError; end
    class NotInitializedError < RuntimeError; end

    include Utils

    DEFAULTS = {
      :repo_dir => (Etc.getpwnam('git') rescue {})[:dir],
      :monit_conf => 'monitrc',
      :monit_reload => '/usr/sbin/monit reload',
      :nginx_conf => 'nginx.conf',
      :nginx_reload => '/usr/sbin/nginx -s reload',
      :logrotate_conf => 'logrotate.conf',
    }

    def self.config_file_template
      File.expand_path('../appserver.yml', __FILE__)
    end

    def self.search_dir (path = Dir.pwd)
      if File.exist?(File.join(path, 'appserver.yml'))
        path
      elsif path =~ %r(/)
        search_dir(path.sub(%r(/[^/]*$), ''))
      else
        nil
      end
    end

    def self.initialize_dir (options = {})
      raise AlreadyInitializedError if search_dir && !options[:force]
      raise DirectoryNotEmptyError if Dir.glob('*') != [] && !options[:force]
      safe_replace_file('appserver.yml') do |f|
        f.puts File.read(config_file_template)
      end
      ['tmp', 'log'].each do |dir|
        Dir.mkdir(dir) if !File.directory?(dir)
      end
    end

    def initialize (options = {})
      super()
      # Search upwards for the appserver dir
      self.dir = self.class.search_dir
      raise NotInitializedError unless dir
      # Load configuration settings
      @config = load_config(config_file)
      DEFAULTS.each do |key, default_value|
        self[key] = @config[key] || default_value
      end
    end

    def config_file
      File.join(dir, 'appserver.yml')
    end

    def tmp_dir
      File.join(dir, 'tmp')
    end

    def log_dir
      File.join(dir, 'log')
    end

    def app (name)
      @apps ||= {}
      @apps[name] ||= App.new(self, name, @config)
    end

    def apps
      Dir.glob(File.join(dir, '*')).select { |f| File.directory?(f) }.map { |f| File.basename(f) }.map { |name| app(name) }
    end

    def repository (name_or_path)
      path = name_or_path =~ %r(/) ? expand_path(name_or_path) : File.expand_path("#{name_or_path}.git", repo_dir)
      @repositories ||= {}
      @repositories[path] ||= Repository.new(self, path, @config)
    end

    def repositories
      Dir.glob(File.join(repo_dir, '*.git')).select { |f| File.directory?(f) }.map { |path| repository(path) }
    end

    def write_configs
      # Write Monit configuration snippet
      safe_replace_file(monit_conf) do |f|
        f.puts %Q(# Monit configuration automagically generated by the "appserver" gem using)
        f.puts %Q(# the appserver directory config #{expand_path(config_file)})
        f.puts %Q(# Include this file into your system's monitrc (using an include statement))
        f.puts %Q(# to use it. See http://github.com/zargony/appserver for details.)
        # Let Monit reload itself if this configuration changes
        f.puts %Q(check file monit_conf with path #{expand_path(monit_conf)})
        f.puts %Q(  if changed checksum then exec "#{monit_reload}")
        # Reload Nginx if its configuration changes
        f.puts %Q(check file nginx_conf with path #{expand_path(nginx_conf)})
        f.puts %Q(  if changed checksum then exec "#{nginx_reload}")
        # Add application-specific Monit configuration
        apps.each do |app|
          app.write_monit_config(f)
        end
      end
      # Write Nginx configuration snippet
      safe_replace_file(nginx_conf) do |f|
        f.puts %Q(# Nginx configuration automagically generated by the "appserver" gem using)
        f.puts %Q(# the appserver directory config #{expand_path(config_file)})
        f.puts %Q(# Include this file into your system's nginx.conf \(using an include statement)
        f.puts %Q(# inside a http statement\) to use it. See http://github.com/zargony/appserver)
        f.puts %Q(# for details.)
        # The default server always responds with 403 Forbidden
        f.puts %Q(server {)
        f.puts %Q(  listen 80 default;)
        f.puts %Q(  server_name _;)
        f.puts %Q(  deny all;)
        f.puts %Q(})
        # Add application-specific Nginx configuration
        apps.each do |app|
          app.write_nginx_config(f)
        end
      end
      # Write Logrotate configuration snippet
      safe_replace_file(logrotate_conf) do |f|
        f.puts %Q(# Logrotate configuration automagically generated by the "appserver" gem using)
        f.puts %Q(# the appserver directory config #{expand_path(config_file)})
        f.puts %Q(# Include this file into your system's logrotate.conf \(using an include statement\))
        f.puts %Q(# to use it. See http://github.com/zargony/appserver for details.)
        # TODO
      end
    end

  protected

    def expand_path (path)
      File.expand_path(path, dir)
    end

    def load_config (filename)
      symbolize_keys(YAML.load_file(filename) || {})
    end
  end
end
