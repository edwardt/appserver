require 'git'

module Appserver
  class Repository < Struct.new(:server, :dir)
    class InvalidRepositoryError < RuntimeError; end

    include Utils

    def initialize (server, dir, config)
      self.server, self.dir = server, dir.chomp('/')
      raise InvalidRepositoryError unless valid?
    end

    def name
      File.basename(dir, '.git')
    end

    def app
      # The app for this repository (same name)
      server.app(name)
    end

    def valid?
      File.directory?(File.join(dir, 'hooks')) && File.directory?(File.join(dir, 'refs'))
    end

    def post_receive_hook
      File.join(dir, 'hooks', 'post-receive')
    end

    def install_hook
      deploy_cmd = "#{File.expand_path($0)} -d #{server.dir} deploy #{dir}"
      if !File.exist?(post_receive_hook) || !File.executable?(post_receive_hook)
        puts "Installing git post-receive hook to repository #{dir}..."
        safe_replace_file(post_receive_hook) do |f|
          f.puts '#!/bin/sh'
          f.puts deploy_cmd
          f.chown File.stat(dir).uid, File.stat(dir).gid
          f.chmod 0755
        end
      elsif !File.readlines(post_receive_hook).any? { |line| line =~ /^#{Regexp.escape(deploy_cmd)}/ }
        puts "Couldn't install post-receive hook. Foreign hook script already present in repository #{dir}!"
      else
        #puts "Hook already installed in repository #{dir}"
      end
    end

  protected

    def expand_path (path)
      File.expand_path(path, dir)
    end

    def checkout (path, branch = 'master')
      # There seem to be two ways to "export" the tip of a branch from a repository
      # 1. clone the repository, check out the branch and remove the .git directory afterwards
      #system("git clone --depth 1 --branch master #{dir} #{path} && rm -rf #{path}/.git")
      # 2. do a hard reset while pointing GIT_DIR to the repository and GIT_WORK_TREE to an empty dir
      #system("mkdir #{path} && git --git-dir=#{dir} --work-tree=#{path} reset --hard #{branch}")

      # We use the Git.export from the git gem here, which uses the first
      # method (and handles errors more nicely than a uing system())
      Git.export(dir, path, :branch => branch)
    end
  end
end
