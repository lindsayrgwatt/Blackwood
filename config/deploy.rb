require 'bundler/capistrano'

set :application, "blackwood"

set :rvm_ruby_string, "ruby-1.9.3-p125"
require "rvm/capistrano" # Load RVM's capistrano plugin.

before 'deploy:setup', 'rvm:install_rvm'
before 'deploy:setup', 'rvm:install_ruby'
before 'deploy:setup', "ubuntu:required_packages"
before 'deploy:setup', 'ubuntu:service_gems'
after "deploy:update", "foreman:export"
after "deploy:update", "foreman:restart"

task :production do
  set :gateway, 'beagle.placeling.com:11235'
  server '10.122.167.104', :app, :web, :db, :scheduler, :primary => true
  ssh_options[:forward_agent] = true #forwards local-localhost keys through gateway
  set :user, 'ubuntu'
  set :use_sudo, false
  set :rails_env, "production"
end

task :staging do
  server 'staging.placeling.com', :app, :web, :db, :scheduler, :primary => true
  ssh_options[:forward_agent] = true
  set :deploy_via, :remote_cache
  set :user, 'ubuntu'
  set :port, '11235'
  set :use_sudo, false
  set :rails_env, "staging"
end

default_run_options[:pty] = true # Must be set for the password prompt from git to work
set :repository, "git@github.com:placeling/Blackwood.git" # Your clone URL
set :scm, "git"

set :deploy_to, "/var/www/apps/#{application}"
set :shared_directory, "#{deploy_to}/shared"
set :deploy_via, :remote_cache

namespace :ubuntu do
  task :required_packages, :roles => :app do
    run 'sudo apt-get update'
    run 'sudo apt-get install git-core ruby  ruby-dev rubygems libxslt-dev libxml2-dev libcurl4-openssl-dev imagemagick nodejs'
    run 'sudo apt-get install zlib1g-dev libssl-dev libyaml-dev libsqlite3-0  libsqlite3-dev sqlite3 libxml2-dev libxslt-dev  autoconf libc6-dev ncurses-dev'
    run 'sudo apt-get install upstart build-essential bison openssl libreadline6 libreadline6-dev curl libtool libpcre3 libpcre3-dev'
  end

  task :service_gems, :roles => :app do
    run 'sudo gem install bundler passenger scout request-log-analyzer'
  end
end


def run_remote_rake(rake_cmd)
  rake_args = ENV['RAKE_ARGS'].to_s.split(',')
  cmd = "cd #{fetch(:latest_release)} && #{fetch(:rake, "rake")} RAILS_ENV=#{fetch(:rails_env, "production")} #{rake_cmd}"
  cmd += "['#{rake_args.join("','")}']" unless rake_args.empty?
  run cmd
  set :rakefile, nil if exists?(:rakefile)
end


namespace :deploy do
  task :start, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end

  task :stop, :roles => :app do
    # Do nothing.
  end

  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end

end

### Foreman-related snippet of `config/deploy.rb` below.
### Rest of the file omitted!

namespace :foreman do
  desc 'Export the Procfile to Ubuntu upstart scripts'
  task :export, :roles => :app do
    run "cd #{release_path} && rvmsudo env PATH=$PATH bundle exec foreman export upstart /etc/init -e #{release_path}/config/foreman_#{rails_env}.env -a #{application} -u #{user} -l #{release_path}/log/foreman"
  end

  desc "Start the application services"
  task :start, :roles => :app do
    sudo "start #{application}"
  end

  desc "Stop the application services"

  task :stop, :roles => :app do
    sudo "stop #{application}"
  end

  desc "Restart the application services"
  task :restart, :roles => :app do
    run "sudo start #{application} || sudo restart #{application}"
  end
end

require './config/boot'