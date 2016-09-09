# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, "typestry"
set :repo_url,  "git@gitlab.pramati.com:Fontli/Backend.git"

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/data/www/typestry'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/mongoid.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{log tmp/pids tmp/cache public/system public/photos public/avatars public/assets config/certs}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5
#
set :rvm_type, :system
set :rvm_ruby_version, '1.9.3-p547@fontli'

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      within release_path do
        # execute 'custom script'
      end
    end
  end

  #cap development deploy:invoke task=task_namespace:task_name
  #e.g. cap development deploy:invoke task=photos:verify_likes_count
  desc 'Invoke rake task on the server'
  task :invoke do
    on roles(:app), in: :sequence, wait: 15 do
      within release_path do
        with rails_env: :production do
          execute :rake, ENV['task']
        end
      end
    end
  end
end
