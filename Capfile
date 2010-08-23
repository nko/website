load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

default_run_options[:pty] = true

set :application, "nko"
set :repository,  "git://github.com/nko/website.git"
set :scm, :git
set :deploy_via, :remote_cache

set :user, "app"

role :app, "tmp.nodeknockout.com"

namespace :deploy do
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} restart nko"
    run "#{try_sudo} apache2ctl graceful"
  end
end
