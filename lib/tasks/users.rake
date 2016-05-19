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
end
