namespace :ci do
  task :copy_yml do
    sh "cp #{Rails.root}/config/mongoid.yml.sample #{Rails.root}/config/mongoid.yml"
  end

  desc 'Complete build verification'
  task :verifications do
    exit(1) unless system('rubocop')
    exit(1) unless system('brakeman -qz')
    exit(1) unless system('bundle exec bundle-audit update && bundle exec bundle-audit check')
    puts 'VERIFICATIONS PASSED'
  end

  desc 'build code coverage using simplecov'
  task :simplecov do
    Rake::Task["simplecov"].execute
    puts 'PASSED'
  end

  desc "Prepare for CI and run entire test suite"
  task :run => ['ci:copy_yml', 'ci:verifications', 'ci:simplecov'] do
  end
end
