class AdminPresenter
  def initialize
  end

  def users_count
    User.count
  end

  def photos_count
    Photo.count
  end

  def homepage_photos_count
    Photo.for_homepage.count
  end

  def current_stat
    Stat.current
  end

  def online_users_count
    ApiSession.where(:expires_at.gt => Time.zone.now + 40.weeks - 5.minutes).count
  end

  def sos_count
    Photo.sos_approved.count
  end

  def sos_with_responses_count
    Photo.sos_approved.where(:comments_count.gt => 0).count
  end
  
  def users_with_least_followers_count
    User.all.select{|u| u.followers_count >= 3 }.count
  end

  def users_with_least_follows_count
    User.all.select{|u| u.follows_count >= 6 }.count
  end

  def new_users_count 
    User.where(:created_at.gte => Time.now.beginning_of_month).count
  end

  def users_in_past_30_days 
    User.where(:created_at.gte => 30.days.ago).count
  end

  def users_with_photos
    Photo.distinct(:user_id).count
  end

  def users_with_one_photo
    Photo.collection.aggregate({ "$match" => { caption: {'$ne' =>  Photo::DEFAULT_TITLE}, 
                                   flags_count: {'$lt' => Photo::ALLOWED_FLAGS_COUNT}}},
                               { '$group' => {_id: '$user_id', 'photos_count' => { "$sum" => 1 }}},
                               {"$match" => { photos_count: 1}}).count
  end

  def login_medium
    ['email'].concat(User::PLATFORMS).collect(&:titleize).join(', ')
  end

  def shared_post_count
    Share.pluck(:photo_id).uniq.count
  end

  def users_sharing_to_other_platforms
    Share.pluck(:user_id).uniq.count
  end

  def most_photographed_location
    Photo.collection.aggregate([{"$group" => { "_id" => { address: "$address"}, "photos_count" => { "$sum" => 1 }}},{ "$sort" => { "photos_count" => -1 }}, { '$limit' => 1 }]).first['_id']['address']
  end
end
