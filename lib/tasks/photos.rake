namespace :photos do

  desc "Shift Photos from local machine to AWS S3"
  task :export_to_aws => :environment do
    AWS_API_CONFIG = YAML::load_file(File.join(Rails.root, 'config/aws_s3.yml'))[Rails.env].symbolize_keys
    AWS_BUCKET = AWS_API_CONFIG.delete(:bucket)
    AWS_STORAGE_CONNECTIVITY =  Fog::Storage.new(AWS_API_CONFIG)
    THUMBNAILS = { :large => '640x640', :medium => '320x320', :thumb => '150x150' }
    logger = Logger.new("#{Rails.root}/log/aws_storage.log")

    Photo.all.order("created_at asc").each do |photo|
      extension = File.extname(photo.data_filename).gsub(/\.+/, '')
      file_data = [:original] + THUMBNAILS.keys
      file_data.each do |filepath|
        if File::exists?(photo.path(filepath))
          file_obj = File.open(photo.path(filepath))
          AWS_STORAGE_CONNECTIVITY.directories.get(AWS_BUCKET).files.create(:key => photo.aws_path(filepath), :body => file_obj, :public => true, :content_type => extension)
        end
      end
      logger.info("Photo - #{photo.id} - moved to S3 at #{photo.created_at}")
    end
  end

  desc "Verify likes_count of all photos with likes.count"
  task :verify_likes_count => :environment do
    last_ran_at = Stat.current.photo_likes_count_checked_at
    start = Time.now.utc
    count = 0

    Photo.in_batches(100, :created_at.gt => last_ran_at) do |photos|
      photos.each do |photo|
        next if photo.likes_count == photo.likes.count
      	Photo.reset_counters(photo.id, :likes)
        count += 1
      end # photos
    end # batches

    Photo.where(:likes_count.lt => 0).each do |photo|
      Photo.reset_counters(photo.id, :likes)
      count += 1
    end

    Stat.current.update_attribute(:photo_likes_count_checked_at, Time.now.utc - 5.minutes) # 5 mins buffer
    puts "Completed in #{(Time.now.utc - start) / 60} mins."
    puts "Updated #{count} photos with correct likes_count."
  end

  desc "Verify all thumbnails are available in S3 and are of correct dimensions"
  task :verify_thumbnails => :environment do
    Fog::Logger[:warning] = nil # suppress s3 bucket name warnings
    logger = Logger.new('verify_thumbnails_report.rb')
    logger.info "#### Report on #{Time.now.utc} ######"

    aws_dir = Photo::AWS_STORAGE_CONNECTIVITY.directories.get(Photo::AWS_BUCKET)
    thumbs = Photo::THUMBNAILS
    last_ran_at = Stat.current.photo_verify_thumbs_ran_at || Photo.asc(:created_at).first.created_at
    missing, size_issues = {}, {}
    start = Time.now.utc

    Photo.in_batches(1000, :created_at.gt => last_ran_at) do |fotos|
      fotos.each do |f|
        foto_size = {}
        thumbs.each do |style, size|
          file = aws_dir.files.head(f.aws_path(style))
          foto_size[style] = 0

          if file
            foto_size[style] = file.content_length
          else
            missing[f.id.to_s] ||= []
            missing[f.id.to_s] << style
          end
        end # thumbs

        miss = missing[f.id.to_s]
        if foto_size[:large] <= foto_size[:medium] && (miss.nil? || !miss.include?(:large))
          size_issues[f.id.to_s] ||= []
          size_issues[f.id.to_s] << :large
        end

        if foto_size[:medium] <= foto_size[:thumb] && (miss.nil? || !miss.include?(:medium))
          size_issues[f.id.to_s] ||= []
          size_issues[f.id.to_s] << :medium
        end
      end # fotos
    end # batches

    Stat.current.update_attribute(:photo_verify_thumbs_ran_at, Time.now.utc - 5.minutes) # 5 mins buffer

    logger.info "@missing = #{missing}"
    logger.info "@size_issues = #{size_issues}"
    logger.info "#####################################"
    puts "Completed in #{(Time.now.utc - start) / 60} mins."
    puts "Detected #{size_issues.length} size issues and #{missing.length} missing issues"
  end

  desc "Fix missing medium/thumb sizes or incorrect photo thumbnail dimensions in S3"
  task :fixup_thumbnails => :verify_thumbnails do
    require File.join(Rails.root, 'verify_thumbnails_report.rb')
    Fog::Logger[:warning] = nil # suppress s3 bucket name warnings
    aws_dir = Photo::AWS_STORAGE_CONNECTIVITY.directories.get(Photo::AWS_BUCKET)
    missing_fixed = missing_failed = size_issue_fixed = size_issue_failed = 0
    puts "\n\nTrying to fixup thumbnails..."
    start = Time.now.utc

    total_missing = @missing.length

    @missing.each do |id, styles|
      orig_fpath, orig_file = "#{id}_original.jpg", nil
      # we need the :large version or the orig file to fix the rest, else move on
      if styles.include?(:large) && (orig_file = aws_dir.files.get(orig_fpath)).nil?
        puts "Can't fix photo #{id}. Its missing original, #{styles.join(', ')}"
        next
      end
      
      s3_file = orig_file || aws_dir.files.get("#{id}_large.jpg")
      File.open('image.jpg', 'wb') { |fp| fp.write(s3_file.body) }

      styles.each do |style|
        size = Photo::THUMBNAILS[style]
        res = system("convert image.jpg -resize '#{size}' -quality 85 -strip -unsharp 0.5x0.5+0.6+0.008 image_conv.jpg")
        res ? missing_fixed += 1 : missing_failed += 1

        new_file = File.open('image_conv.jpg')
        aws_dir.files.create(
          :key => "#{id}_#{style.to_s}.jpg",
          :body => new_file,
          :public => true,
          :content_type => 'image/jpg'
        )
        new_file.close
      end

      total_processed = missing_fixed + missing_failed
      if total_missing > 5 && (total_processed % 5).zero?
        # if there's more than 1 style missing on a photo, this message will look weird.
        puts "Processed #{total_processed}/#{total_missing} photos..."
      end
    end

    @size_issues.each do |id, styles|
      orig_fpath, orig_file = "#{id}_original.jpg", nil
      # we need the :large version or the orig file to fix the rest, else move on
      if styles.include?(:large) && (orig_file = aws_dir.files.get(orig_fpath)).nil?
        puts "Can't fix photo #{id}. Its missing original and has size issues for #{styles.join(', ')}"
        next
      end

      s3_file = orig_file || aws_dir.files.get("#{id}_large.jpg")
      File.open('image.jpg', 'wb') { |fp| fp.write(s3_file.body) }

      styles.each do |style|
        size = Photo::THUMBNAILS[style]
        res = system("convert image.jpg -resize '#{size}' -quality 85 -strip -unsharp 0.5x0.5+0.6+0.008 image_conv.jpg")
        res ? size_issue_fixed += 1 : size_issue_failed += 1

        new_file = File.open('image_conv.jpg')
        file = aws_dir.files.get("#{id}_#{style.to_s}.jpg")
        file.body = new_file
        file.save
        new_file.close
      end
    end

    Stat.current.update_attribute(:photo_fixup_thumbs_ran_at, Time.now.utc - 5.minutes) # 5 mins buffer

    puts "Completed in #{(Time.now.utc - start) / 60} mins."
    puts "Fixed #{size_issue_fixed} size issues and #{missing_fixed} missing issues"
    puts "Failed to fix #{size_issue_failed} size issues and #{missing_failed} missing issues"
  end

  desc "Reset likes_count of all photos"
  task :reset_likes_count => :environment do
    progressbar = ProgressBar.create format: "%a %e %P% Processed: %c from %C"
    progressbar.total = Photo.count

    Photo.in_batches(100) do |photos|
      photos.each do |p|
        next if p.likes_count == p.likes.count
        Photo.reset_counters(p.id, :likes)
        progressbar.increment
      end    
    end
  end

  desc "Reset fonts_count of all photos"
  task :reset_fonts_count => :environment do
    progressbar = ProgressBar.create format: "%a %e %P% Processed: %c from %C"
    progressbar.total = Photo.count

    Photo.in_batches(100) do |photos|
      photos.each do |p|
        next if p.fonts_count == p.fonts.count
        Photo.reset_counters(p.id, :fonts)
        progressbar.increment
      end    
    end
  end
  
  desc "Set font help of requested SoS"
  task :fix_requested_sos => :environment do
    Photo.where(:font_help => false, :sos_requested_at.ne => nil).update_all(:font_help => true)
  end

  desc "Reset flags_count of photos"
  task :reset_flags_count => :environment do
    flagged_photos =  Photo.unscoped.where(:flags_count.gte => Photo::ALLOWED_FLAGS_COUNT)

    progressbar = ProgressBar.create(format: "%a %e %P% Processed: %c from %C", total: flagged_photos.count)

    flagged_photos.each do |photo|
      next if photo.flags_count == photo.flags.count
      Photo.unscoped.reset_counters(photo.id, :flags)
      progressbar.increment
    end
  end
end
