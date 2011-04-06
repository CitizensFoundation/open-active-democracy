require 'bundler/capistrano'

namespace :thinking_sphinx do
  namespace :install do
    desc <<-DESC
        Install Sphinx by source
        
        If Postgres is available, Sphinx will use it.
        
        If the variable :thinking_sphinx_configure_args is set, it will
        be passed to the Sphinx configure script. You can use this to
        install Sphinx in a non-standard location:
        
          set :thinking_sphinx_configure_args, "--prefix=$HOME/software"
DESC

    task :sphinx do
      with_postgres = false
      begin
        run "which pg_config" do |channel, stream, data|
          with_postgres = !(data.nil? || data == "")
        end
      rescue Capistrano::CommandError => e
        puts "Continuing despite error: #{e.message}"
      end
    
      args = []
      if with_postgres
        run "pg_config --pkgincludedir" do |channel, stream, data|
          args << "--with-pgsql=#{data}"
        end
      end
      args << fetch(:thinking_sphinx_configure_args, '')
      
      commands = <<-CMD
      wget -q http://www.sphinxsearch.com/downloads/sphinx-0.9.8.1.tar.gz >> sphinx.log
      tar xzvf sphinx-0.9.8.1.tar.gz
      cd sphinx-0.9.8.1
      ./configure #{args.join(" ")}
      make
      #{try_sudo} make install
      rm -rf sphinx-0.9.8.1 sphinx-0.9.8.1.tar.gz
      CMD
      run commands.split(/\n\s+/).join(" && ")
    end
  
    desc "Install Thinking Sphinx as a gem from GitHub"
    task :ts do
      run "#{try_sudo} gem install thinking-sphinx --source http://gemcutter.org"
    end
  end

  desc "Generate the Sphinx configuration file"
  task :configure do
    rake "thinking_sphinx:configure"
  end

  desc "Index data"
  task :index do
    rake "thinking_sphinx:index"
  end

  desc "Start the Sphinx daemon"
  task :start do
    configure
    rake "thinking_sphinx:start"
  end

  desc "Stop the Sphinx daemon"
  task :stop do
    configure
    rake "thinking_sphinx:stop"
  end

  desc "Stop and then start the Sphinx daemon"
  task :restart do
    stop
    start
  end

  desc "Stop, re-index and then start the Sphinx daemon"
  task :rebuild do
    stop
    index
    start
  end

  desc "Add the shared folder for sphinx files"
  task :shared_sphinx_folder, :roles => :web do
    rails_env = fetch(:rails_env, "production")
    run "mkdir -p #{shared_path}/sphinx/#{rails_env}"
  end

  def rake(*tasks)
    rails_env = fetch(:rails_env, "production")
    rake = fetch(:rake, "rake")
    tasks.each do |t|
      run "if [ -d #{release_path} ]; then cd #{release_path}; else cd #{current_path}; fi; #{rake} RAILS_ENV=#{rails_env} #{t}"
    end
  end
end

set :whenever_command, "bundle exec whenever"
require "whenever/capistrano"

set :application, "open-active-democracy"
set :domain, "o2"
set :selected_branch, "master"
set :repository, "git://github.com/rbjarnason/open-active-democracy.git"
set :use_sudo, false
set :deploy_to, "/home/yrpri/sites/#{application}/#{selected_branch}"
set :branch, "#{selected_branch}"
set :user, "yrpri"
set :deploy_via, :remote_cache

set :scm, "git"

role :app, domain
role :web, domain
role :db,  domain, :primary => true

namespace :delayed_job do 
    desc "Restart the delayed_job process"
    task :restart, :roles => :app do
      run "cd #{current_path}; RAILS_ENV=production ruby script/delayed_job stop RAILS_ENV=production"
      run "cd #{current_path}; RAILS_ENV=production ruby script/delayed_job start RAILS_ENV=production"
  #    run "cd #{current_path}; RAILS_ENV=production ruby script/delayed_job restart RAILS_ENV=production"
    end
end

after "deploy:update", "delayed_job:restart"

task :before_update_code, :roles => [:app] do
  thinking_sphinx.stop
end

task :after_update_code do
  run "ln -nfs #{deploy_to}/#{shared_dir}/db/sphinx #{current_release}/db/sphinx"
  run "ln -nfs #{deploy_to}/#{shared_dir}/config/yrprirsakey.pem #{current_release}/config/yrprirsakey.pem"
  run "ln -nfs #{deploy_to}/#{shared_dir}/config/yrprirsacert.pem #{current_release}/config/yrprirsacert.pem"
  run "ln -s   #{deploy_to}/#{shared_dir}/config/contacts.yml #{current_release}/config/contacts.yml"
  run "ln -s   #{deploy_to}/#{shared_dir}/config/database.yml #{current_release}/config/database.yml"
  run "ln -s   #{deploy_to}/#{shared_dir}/config/facebooker.yml #{current_release}/config/facebooker.yml"
  run "ln -s   #{deploy_to}/#{shared_dir}/config/newrelic.yml #{current_release}/config/newrelic.yml"
  run "ln -nfs #{deploy_to}/#{shared_dir}/config/twitter_auth.yml #{current_release}/config/twitter_auth.yml"
  run "ln -nfs /mnt/shared/system #{current_release}/public/system"
  thinking_sphinx.configure
  thinking_sphinx.start
end

namespace :deploy do
  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

deploy.task :start do
# nothing
end

Dir[File.join(File.dirname(__FILE__), '..', 'vendor', 'gems', 'hoptoad_notifier-*')].each do |vendored_notifier|
  $: << File.join(vendored_notifier, 'lib')
end

require 'hoptoad_notifier/capistrano'
