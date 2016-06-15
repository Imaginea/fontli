require 'ruby-progressbar'
namespace :users do
  desc "Update users photos_count"
  task :update_photos_count => :environment do
    progressbar = ProgressBar.create format: "%a %e %P% Processed: %c from %C"
    progressbar.total = User.non_admins.count
    User.non_admins.includes(:photos).all.each do |u|
      u.update_attribute(:photos_count, u.photos.count)
      progressbar.increment
    end
  end

  desc "Update users api_access_token"
  task :update_api_access_token => :environment do
    progressbar = ProgressBar.create format: "%a %e %P% Processed: %c from %C"
    progressbar.total = User.where(:extuid.ne => nil, :api_access_token => nil).count
    User.where(:extuid.ne => nil, :api_access_token => nil).all.each do |u|
      u.update_attribute(:api_access_token, Digest::MD5.hexdigest(u.extuid))
      progressbar.increment
    end
  end
end
