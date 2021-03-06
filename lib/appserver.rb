module Appserver
  ROOT = File.expand_path('..', __FILE__) unless const_defined?(:ROOT)
  autoload :Utils,        "#{ROOT}/appserver/utils"
  autoload :Command,      "#{ROOT}/appserver/command"
  autoload :Configurator, "#{ROOT}/appserver/configurator"
  autoload :ServerDir,    "#{ROOT}/appserver/server_dir"
  autoload :App,          "#{ROOT}/appserver/app"
  autoload :Repository,   "#{ROOT}/appserver/repository"
  autoload :Monit,        "#{ROOT}/appserver/monit"
  autoload :Nginx,        "#{ROOT}/appserver/nginx"
  autoload :Logrotate,    "#{ROOT}/appserver/logrotate"
end
