require 'test_helper'

describe User do
  let(:photo_data)    { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/everlast.jpg', 'image/jpeg') }
  let(:user)          { create(:user) }
  let(:admin_user)    { create(:user, :admin) }
  let(:expert_user)   { create(:user, :expert) }
  let(:app_user)      { create(:user, :with_platform) }
  let(:inactive_user) { create(:user, active: false) }
  let(:collection)    { create(:collection) }
  let(:collection1)   { create(:collection) }
  let(:photo)         { create(:photo, user: user) }
  let(:like)          { create(:like, user: user) }
  let(:font)          { create(:font) }
  let(:comment)       { create(:comment) }
  let(:follow)        { create(:follow, user: admin_user, follower_id: user.id) }

  subject { User }

  before do
    create(:user, username: 'fontli')
    ActionMailer::Base.deliveries = []
  end

  it { must have_fields(:username, :full_name, :email, :hashed_password, :salt, :description).of_type(String) }
  it { must have_fields(:website, :avatar_filename, :avatar_content_type).of_type(String) }
  it { must have_fields(:avatar_size).of_type(Integer) }
  it { must have_fields(:avatar_dimension, :extuid, :iphone_token).of_type(String) }
  it { must have_fields(:platform).of_type(String).with_default_value('default') }
  it { must have_fields(:iphone_token_updated_at).of_type(DateTime) }
  it { must have_fields(:android_registration_id, :wp_toast_url).of_type(String) }
  it { must have_fields(:admin, :expert).of_type(Boolean).with_default_value(false) }
  it { must have_fields(:points).of_type(Integer).with_default_value(5) }
  it { must have_fields(:active).of_type(Boolean).with_default_value(true) }
  it { must have_fields(:suspended_reason).of_type(String) }
  it { must have_fields(:fav_fonts_count, :fav_workbooks_count).of_type(Integer).with_default_value(0) }
  it { must have_fields(:likes_count, :user_flags_count).of_type(Integer).with_default_value(0) }
  it { must have_fields(:show_in_header).of_type(Boolean).with_default_value(false) }
  it { must have_fields(:followed_collection_ids).of_type(Array).with_default_value([]) }

  it { must have_index_for(:username) }
  it { must have_index_for(:email) }

  it { must have_many(:workbooks) }
  it { must have_many(:photos) }
  it { must have_many(:collections) }
  it { must have_many(:fonts) }
  it { must have_many(:font_tags) }
  it { must have_many(:fav_fonts) }
  it { must have_many(:fav_workbooks) }
  it { must have_many(:notifications) }
  it { must have_many(:sent_notifications) }
  it { must have_many(:follows) }
  it { must have_many(:my_followers) }
  it { must have_many(:likes) }
  it { must have_many(:comments) }
  it { must have_many(:mentions) }
  it { must have_many(:agrees) }
  it { must have_many(:flags) }
  it { must have_many(:user_flags) }
  it { must have_many(:invites) }
  it { must have_many(:shares) }
  it { must have_many(:suggestions) }
  it { must have_many(:sessions) }

  it { must validate_presence_of(:username) }
  it { must validate_presence_of(:password) }

  it { must validate_length_of(:username).within(5..15) }

  it { must validate_format_of(:username).to_not_allow('test user') }
  it { must validate_format_of(:username).to_allow('Test5') }

  it { must validate_format_of(:email).to_allow('test_user@example.com') }
  it { must validate_format_of(:email).to_not_allow('test_user_example_com') }

  it { must validate_inclusion_of(:avatar_size).to_allow(0..(3.megabytes)).with_message('should be less than 3MB') }
  it { must validate_inclusion_of(:avatar_content_type).to_allow(User::ALLOWED_TYPES).with_message('should be jpg/gif') }

  it { must validate_presence_of(:email) }
  it { must validate_uniqueness_of(:email) }
  it { must validate_presence_of(:extuid) }
  it { must validate_length_of(:password).within(6..15) }

  it 'should be invalid if password confirmation is not same as password' do
    new_user = build(:user)
    new_user.password = 'password'
    new_user.password_confirmation = ''
    new_user.must_be :invalid?
    new_user.errors.must_include(:password)
  end

  describe 'callback' do
    let(:new_user) { build(:user) }

    describe 'before_save' do
      it 'should set hashed password' do
        new_user.hashed_password.must_be_nil
        new_user.save
        new_user.hashed_password.wont_be_nil
      end
    end

    describe 'after_save' do
      it 'should set avatar' do
        new_user.avatar = photo_data
        new_user.save
        new_user.url.wont_be_nil
      end
    end

    describe 'after_destroy' do
      it 'should delete the directory of user avatar' do
        user_with_photo = create(:user, :with_avatar)
        File.directory?(User::FOTO_DIR + "/#{user_with_photo.id}").must_equal true

        user_with_photo.destroy
        File.directory?(User::FOTO_DIR + "/#{user_with_photo.id}").must_equal false
      end
    end
  end

  describe 'scope' do
    let(:user1)         { create(:user, user_flags_count: 2) }
    let(:user2)         { create(:user, user_flags_count: 3) }

    before do
      user
      inactive_user
    end

    it 'should return active users' do
      User.all.must_include user
    end

    it 'should not return inactive users' do
      User.all.wont_include inactive_user
    end

    it 'should return users whose flags count is less than 3' do
      User.all.must_include user1
    end

    it 'should not return users whose flags count is greater than or equal 3' do
      User.all.wont_include user2
    end

    describe '.non_admins' do
      it 'should return non admin user' do
        User.non_admins.must_include user
      end

      it 'should not return admin user' do
        User.non_admins.wont_include admin_user
      end
    end

    describe '.experts' do
      it 'should return expert users' do
        User.experts.must_include expert_user
      end

      it 'should not return non expert users' do
        User.experts.wont_include user
      end
    end

    describe '.leaders' do
      it 'should return leaders' do
        User.leaders.must_include user
      end

      it 'should not return users who are not leader' do
        User.leaders.wont_include admin_user
      end
    end

    describe '.following_collection' do
      before do
        user.followed_collection_ids << collection.id
        user.save
      end

      it 'should return the users who are following the provided collection' do
        User.following_collection(collection.id).must_include user
      end

      it 'should not return the users who are not following the provided collection' do
        User.following_collection(collection.id).wont_include admin_user
      end
    end
  end

  describe '.[]' do
    it 'should return user found with the provided name' do
      User[user.username].must_equal user
    end
  end

  describe '.fontli' do
    it 'should return user whose username is fontli' do
      User.fontli.username.must_equal 'fontli'
    end
  end

  describe '.by_id' do
    it 'should return a user found with the provided id' do
      User.by_id(user.id).must_equal user
    end
  end

  describe '.by_extid' do
    before do
      app_user
    end

    it 'should return a user found with the provide extuid' do
      User.by_extid(app_user.extuid).must_equal app_user
    end
  end

  describe '.by_uname_or_email' do
    it 'should return a user found by the provided username' do
      User.by_uname_or_email(user.username).must_equal user
    end

    it 'should return a user found by the provided email' do
      User.by_uname_or_email(admin_user.email).must_equal admin_user
    end
  end

  describe '.search' do
    let(:other_user) { create(:user, :with_fullname) }

    it 'should return users having the provided username' do
      User.search(user.username).must_include user
    end

    it 'should return users having the provided full_name' do
      User.search(other_user.full_name).must_include other_user
    end
  end

  describe '.search_autocomplete' do
    let(:other_user) { create(:user, :with_fullname) }

    it 'should return array of names of users having the provided username' do
      User.search_autocomplete(user.username).must_include user.username
    end

    it 'should return array of names of users having the provided full_name' do
      User.search_autocomplete(other_user.full_name).must_include other_user.full_name
    end
  end

  describe '.login' do
    it 'should return a user found with the provided username/email and password' do
      User.login(user.username, user.password).must_equal user
    end

    it 'should be nil if user not found with the provided username/email and password' do
      User.login(user.username, 'Wrong Password').must_be_nil
    end
  end

  describe '.api_login' do
    let(:device_id) { SecureRandom.hex(6) }

    it 'should return unable to login error' do
      User.api_login(user.username, 'Wrong Password', device_id).must_equal [nil, :unable_to_login]
    end

    it 'should activate the user session' do
      User.api_login(user.username, user.password, device_id).wont_be_nil
      user.sessions.last.active?.must_equal true
    end
  end

  describe '.check_login_for' do
    before do
      app_user
    end

    it 'should return user not found error' do
      User.check_login_for(SecureRandom.hex(5)).must_equal [nil, :user_not_found]
    end

    it 'should return true' do
      User.check_login_for(app_user.extuid).must_equal true
    end
  end

  describe '.forgot_pass' do
    let(:other_user) { create(:user, :with_platform, email: nil) }

    it 'should return user not found error' do
      User.forgot_pass(Faker::Name.name).must_equal [nil, :user_not_found]
    end

    it 'should return email not set error' do
      User.forgot_pass(other_user.username).must_equal [nil, :user_email_not_set]
    end

    it 'should return true' do
      User.forgot_pass(user.username).must_equal true
      ActionMailer::Base.deliveries.count.must_equal 1
    end
  end

  describe '.human_attribute_name' do
    it 'should transform attributes key name in humane format' do
      User.human_attribute_name('avatar_filename').must_equal 'Filename'
      User.human_attribute_name('avatar_size').must_equal 'File size'
      User.human_attribute_name('avatar_content_type').must_equal 'File type'
    end
  end

  describe '.liked_photo' do
    it 'should return blank array' do
      User.liked_photo(SecureRandom.hex(4)).must_be_empty
    end

    it 'should users who like the provided photo' do
      User.liked_photo(like.photo_id).must_include user
    end
  end

  describe '.add_flag_for' do
    it 'should add flag for a user' do
      user.user_flags.count.must_equal 0
      User.add_flag_for(user.id, admin_user.id)
      user.user_flags.count.must_equal 1
    end

    it 'should return user not found' do
      User.add_flag_for(SecureRandom.hex(4), admin_user).must_equal [nil, :user_not_found]
    end
  end

  describe '#all_expert_ids' do
    before do
      expert_user
    end

    it 'should return expert user ids' do
      User.all_expert_ids.must_include expert_user.id
    end
  end

  describe '#inactive_ids' do
    before do
      inactive_user
    end

    it 'should return inactive user ids' do
      User.inactive_ids.must_include inactive_user.id
    end
  end

  describe '.cached_popular' do
    before do
      create_list(:photo, 5, user: user, created_at: Time.now.utc)
      user.reload
    end
    it 'should return popular users having minimum 5 posts' do
      User.cached_popular.must_include user
    end
  end

  describe '.recommended' do
    before do
      create_list(:photo, 5, user: user, created_at: Time.now.utc)
      user.reload
    end

    it 'should return popular users having minimum 5 posts' do
      User.recommended.must_include user
    end
  end

  describe '.random_popular' do
    let(:popular_user) { create(:user, show_in_header: true) }
    before do
      create_list(:photo, 5, user: popular_user, created_at: Time.now.utc)
      popular_user.reload
    end

    it 'should return random popular users having minimum 5 posts and allowed to show in header' do
      User.random_popular.must_include popular_user
    end
  end

  describe '#api_signup' do
    let(:new_user)     { build(:user) }
    let(:other_user)   { build(:user, platform: nil) }
    let(:invalid_user) { build(:user, email: nil) }

    it 'should create a new user' do
      ActionMailer::Base.deliveries.count.must_equal 0
      new_user.new_record?.must_equal true
      new_user.api_signup
      new_user.persisted?.must_equal true
      ActionMailer::Base.deliveries.count.must_equal 1
    end

    it 'should create a new user without a platform' do
      ActionMailer::Base.deliveries.count.must_equal 0
      other_user.new_record?.must_equal true
      other_user.api_signup
      other_user.persisted?.must_equal true
      ActionMailer::Base.deliveries.count.must_equal 1
    end

    it 'should throw error if user is not valid' do
      invalid_user.api_signup.must_equal [nil, ["Email can't be blank"]]
    end
  end

  describe '#check_duplicate_signup' do
    it 'should return nil' do
      app_user = build(:user, :with_platform)
      app_user.check_duplicate_signup.must_be_nil
    end

    it 'should return duplicate signup message' do
      app_user = create(:user, :with_platform)
      app_user.check_duplicate_signup.must_equal [nil, :duplicate_signup]
    end
  end

  describe '#api_reset_pass' do
    it 'should return new password blank message' do
      app_user.api_reset_pass(app_user.password, '', 'new_password').must_equal [nil, :cur_pass_blank]
    end

    it 'should return password not match message' do
      app_user.api_reset_pass('old_password', 'new_password', 'new_password').must_equal [nil, :cur_pass_not_match]
    end

    it 'should return password same as new message' do
      app_user.api_reset_pass(app_user.password, app_user.password, app_user.password).must_equal [nil, :pass_same_as_new_pass]
    end

    it 'should return password mismatch message' do
      app_user.api_reset_pass(app_user.password, 'new_pass', 'new_password').must_equal [nil, :pass_confirmation_mismatch]
    end

    it 'should update the password' do
      app_user.api_reset_pass(app_user.password, 'new_password', 'new_password')
      app_user.pass_match?('new_password').must_equal true
    end
  end

  describe '#guest?' do
    let(:guest_user) { create(:user, username: 'guest') }

    it 'should return true' do
      guest_user.guest?.must_equal true
    end

    it 'should return false' do
      user.guest?.must_equal false
    end
  end

  describe '#hash_password' do
    it 'should return a hash password' do
      user.hash_password.wont_be_nil
    end
  end

  describe '#pass_match?' do
    it 'should return true' do
      user.pass_match?(user.password).must_equal true
    end

    it 'should return false' do
      user.pass_match?('wrong_password').must_equal false
    end
  end

  describe '#avatar=' do
    it 'should set user avatar attributes' do
      user.avatar = photo_data
      user.avatar_filename.must_equal 'everlast.jpg'
      user.avatar_content_type.must_equal 'image/jpeg'
    end
  end

  describe '#delete_avatar' do
    it 'should delete avatar' do
      user_with_photo = create(:user, :with_avatar)
      File.directory?(User::FOTO_DIR + "/#{user_with_photo.id}").must_equal true
      user_with_photo.delete_avatar.must_equal true
      user_with_photo.avatar_filename.must_be_nil
      File.directory?(User::FOTO_DIR + "/#{user_with_photo.id}").must_equal false
    end
  end

  describe '#avatar_url' do
    it 'should set avatar from a url' do
      user.avatar_url = 'image_url'
      user.avatar_filename.must_be_nil
      user.avatar_url = Faker::Avatar.image
      user.avatar_filename.wont_be_nil
    end
  end

  describe '#path' do
    it 'should return avatar path' do
      user_with_photo = create(:user, :with_avatar)
      user_with_photo.path.must_equal "#{User::FOTO_DIR}/#{user_with_photo.id}/#{user_with_photo.avatar_filename}".gsub(".#{user_with_photo.send(:extension)}", "_original.#{user_with_photo.send(:extension)}")
    end

    it 'should return default avatar path' do
      user.path.must_equal User::DEFAULT_AVATAR_PATH.to_s.gsub(/:style/, 'original')
    end
  end

  describe '#url' do
    it 'should return avatar url' do
      user_with_photo = create(:user, :with_avatar)
      user_with_photo.url.must_equal "#{request_domain}/test_avatars/#{user_with_photo.id}/#{user_with_photo.avatar_filename}".gsub(".#{user_with_photo.send(:extension)}", "_original.#{user_with_photo.send(:extension)}")
    end
  end

  describe '#url_thumb' do
    it 'should return thumb avatar url' do
      user_with_photo = create(:user, :with_avatar)
      user_with_photo.url_thumb.must_equal "#{request_domain}/test_avatars/#{user_with_photo.id}/#{user_with_photo.avatar_filename}".gsub(".#{user_with_photo.send(:extension)}", "_thumb.#{user_with_photo.send(:extension)}")
    end
  end

  describe '#url_large' do
    it 'should return large avatar url' do
      user_with_photo = create(:user, :with_avatar)
      user_with_photo.url_large.must_equal "#{request_domain}/test_avatars/#{user_with_photo.id}/#{user_with_photo.avatar_filename}".gsub(".#{user_with_photo.send(:extension)}", "_large.#{user_with_photo.send(:extension)}")
    end
  end

  describe '#user_id' do
    it 'should return its id' do
      user.user_id.must_equal user.id.to_s
    end
  end

  describe '#aspect_fit' do
    let(:image_data) { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/image.jpg', 'image/jpeg') }
    let(:other_user) { create(:user, avatar: image_data) }

    it 'should return image height and width' do
      other_user.aspect_fit(75, 75).must_equal [75, 30]
    end
  end

  describe '#delete_photo' do
    before do
      photo
    end

    it 'should delete photo having the provided photo_id' do
      user.photos.wont_be_empty
      user.delete_photo(photo.id)
      user.reload.photos.must_be_empty
    end
  end

  describe '#follow_user' do
    it 'should create a follower' do
      admin_user.follows.must_be_empty
      admin_user.follow_user(user.id)
      admin_user.reload.follows.wont_be_empty
    end
  end

  describe '#unfollow_friend' do
    before do
      follow
    end

    it 'should return friendship not found message' do
      admin_user.unfollow_friend(expert_user.id).must_equal [nil, :friendship_not_found]
    end

    it 'should remove a follower' do
      admin_user.unfollow_friend(user.id)
      admin_user.reload.follows.must_be_empty
    end
  end

  describe '#following' do
    before do
      follow
    end

    it 'should return true' do
      admin_user.following?(user).must_equal true
    end

    it 'should return false' do
      admin_user.following?(expert_user).must_equal false
    end
  end

  describe '#my_friend?' do
    it 'should return false' do
      user.my_friend?.must_equal false
    end
  end

  describe '#invite_all' do
    let(:frnds)         { [{ platform: 'facebook', email: Faker::Internet.email }] }
    let(:invalid_frnds) { [{ platform: 'facebook' }] }

    it 'should create an invite and return true' do
      user.invite_all(frnds).must_equal true
    end

    it 'should return error' do
      user.invite_all(invalid_frnds).must_equal [nil, ['null:: Either extuid or email is required.']]
    end
  end

  describe '#invites_and_friends' do
    let(:invite) { create(:invite, user: user, platform: 'facebook', email: Faker::Internet.email) }

    before do
      invite
      expert_user
    end

    it 'should return invites' do
      user.invites_and_friends.must_include invite
    end

    it 'should return users with its invite state' do
      user.invites_and_friends.must_include expert_user
    end
  end

  describe '#populate_invite_state' do
    let(:platform)   { 'facebook' }
    let(:invite)     { create(:invite, user: user, platform: platform, extuid: SecureRandom.hex(6)) }
    let(:user1)      { create(:user, extuid: SecureRandom.hex(6), platform: platform) }
    let(:user2)      { create(:user, extuid: SecureRandom.hex(6), platform: platform) }
    let(:admin1)     { create(:user, extuid: SecureRandom.hex(6), platform: platform, admin: true) }
    let(:follow1)    { create(:follow, user: user, follower_id: user2.id) }
    let(:frnds_hash) do
      [{ 'id' => invite.extuid },
       { 'id' => user1.extuid },
       { 'id' => user2.extuid },
       { 'id' => admin1.extuid }]
    end

    before do
      follow1
    end

    it 'should populate invite state' do
      user.populate_invite_state(frnds_hash, platform)
          .must_equal [{ 'id' => invite.extuid, 'invite_state' => 'Invited' },
                       { 'id' => user1.extuid, 'invite_state' => 'User', 'user_id' => user1.id },
                       { 'id' => user2.extuid, 'invite_state' => 'Friend', 'user_id' => user2.id },
                       { 'id' => admin1.extuid, 'invite_state' => 'None' }]
    end
  end

  describe '#friend_ids' do
    before do
      follow
    end

    it 'should return its friend ids' do
      admin_user.friend_ids.must_include user.id
    end

    it 'should not return user ids who are not its friends' do
      admin_user.friend_ids.wont_include expert_user.id
    end
  end

  describe '#friends' do
    before do
      follow
    end

    it 'should return its friends' do
      admin_user.friends.must_include user
    end

    it 'should not return users who are not its friends' do
      admin_user.friends.wont_include expert_user
    end
  end

  describe '#follows_count' do
    before do
      follow
    end

    it 'should return follower count' do
      admin_user.follows_count.must_equal 1
    end
  end

  describe '#followers' do
    before do
      follow
    end

    it 'should return its followers' do
      user.followers.must_include admin_user
    end
  end

  describe '#followers_count' do
    before do
      follow
    end

    it 'should return its followers count' do
      user.followers_count.must_equal 1
    end
  end

  describe '#mentions_list' do
    before do
      follow
    end

    it 'should return its friends' do
      admin_user.mentions_list.must_include user
    end

    it 'should return the user commented on the provided photo' do
      admin_user.mentions_list(comment.photo_id).must_include comment.user
    end
  end

  describe '#photos_count' do
    it 'should return its photos count' do
      photo.user.photos_count.must_equal 1
    end
  end

  describe '#my_photos' do
    it 'should return its photos' do
      photo.user.my_photos.must_include photo
    end
  end

  describe '#popular_photos' do
    it 'should return its popular photos' do
      photo.user.popular_photos.must_include photo
    end
  end

  describe '#my_workbooks' do
    let(:workbook) { create(:workbook) }

    it 'should return its recent workbook' do
      workbook.user.my_workbooks.must_include workbook
    end
  end

  describe '#fav_photos' do
    it 'should return its favourite photos' do
      like.user.fav_photos.must_include like.photo
    end
  end

  describe '#spotted_photos' do
    it 'should return its spotted fonts' do
      font.user.spotted_photos.must_include font.photo
    end

    it 'should return blank if no font is spotted' do
      expert_user.spotted_photos.must_be_empty
    end
  end

  describe '#my_fonts' do
    it 'should return its fonts' do
      font.user.my_fonts.must_include font
    end
  end

  describe '#my_fav_fonts' do
    before do
      create(:fav_font, font: font, user: user)
    end

    it 'should return its favourite fonts' do
      user.my_fav_fonts.must_include font
    end

    it 'should be empty if it does not have favourite fonts' do
      expert_user.my_fav_fonts.must_be_empty
    end
  end

  describe '#fonts_count' do
    before do
      create(:fav_font, font: font, user: user)
      user.reload
    end

    it 'should return its favourite font count' do
      user.fonts_count.must_equal 1
    end

    it 'should be nil if it does not have favourite fonts' do
      expert_user.fonts_count.must_equal 0
    end
  end

  describe '#photo_ids' do
    it 'should return array of its photo ids' do
      photo.user.photo_ids.must_include photo.id
    end

    it 'should be empty if it does not have photos' do
      expert_user.photo_ids.must_be_empty
    end
  end

  describe '#my_fonts_count' do
    it 'should return its fonts count' do
      font.user.my_fonts_count.must_equal 1
    end

    it 'should be nil if it does not have any fonts' do
      expert_user.my_fonts_count.must_equal 0
    end
  end

  describe '#fav_photo_ids' do
    it 'should return its favourite photo ids' do
      like.user.fav_photo_ids.must_include like.photo_id
    end
  end

  describe '#fav_font_ids' do
    before do
      create(:fav_font, font: font, user: user)
    end

    it 'should return favourite font ids' do
      user.fav_font_ids.must_include font.id
    end

    it 'should be empty if no favourite fonts' do
      expert_user.fav_font_ids.must_be_empty
    end
  end

  describe '#commented_photo_ids' do
    it 'should return photo ids on which the user has commented' do
      comment.user.commented_photo_ids.must_include comment.photo_id
    end

    it 'should be empty if user has no comments' do
      expert_user.commented_photo_ids.must_be_empty
    end
  end

  describe '#comments_count' do
    it 'should return the comments count' do
      comment.user.comments_count.must_equal 1
    end
  end

  describe '#notifications_count' do
    before do
      create(:notification, :for_follow, to_user: user)
      create(:notification, :for_follow, to_user: user, unread: false)
    end

    it 'should return the unread notifications count' do
      user.notifications_count.must_equal 1
    end
  end

  describe '#notifs_all_count' do
    before do
      create(:notification, :for_follow, to_user: user)
      create(:notification, :for_follow, to_user: user, unread: false)
    end

    it 'should return all notifications count' do
      user.notifs_all_count.must_equal 2
    end
  end

  describe '#my_updates' do
    let(:notification) { create(:notification, :for_follow, to_user: user) }

    before do
      notification
    end

    it 'should return notifications' do
      user.my_updates.must_include notification
    end
  end

  describe 'network_updates' do
    let(:font_tag) { create(:font_tag, user: user) }
    let(:fav_font) { create(:fav_font, user: user) }
    let(:follow1)  { create(:follow, user: user) }

    before do
      like
      font_tag
      follow
      follow1
      fav_font
    end

    it 'should return empty if friend ids is empty' do
      expert_user.network_updates.must_be_empty
    end

    it 'should return likes of its friends' do
      admin_user.network_updates.must_include like
    end

    it 'should return font tags of its friends' do
      admin_user.network_updates.must_include font_tag
    end

    it 'should return follows of its friends' do
      admin_user.network_updates.must_include follow1
    end

    it 'should return fav fonts of its friends' do
      admin_user.network_updates.must_include fav_font
    end
  end

  describe '#display_name' do
    let(:other_user) { create(:user, :with_fullname) }

    it 'should return its full_name' do
      other_user.display_name.must_equal other_user.full_name
    end

    it 'should return is username' do
      user.display_name.must_equal user.username
    end
  end

  describe '#can_follow?' do
    before do
      follow
    end

    it 'should return false' do
      user.can_follow?(user).must_equal false
    end

    it 'should return false if its already a friend' do
      admin_user.can_follow?(user).must_equal false
    end

    it 'should return true' do
      expert_user.can_follow?(user).must_equal true
    end
  end

  describe '#can_flag?' do
    it 'should return false' do
      user.can_flag?(user).must_equal false
    end

    it 'should return true' do
      expert_user.can_flag?(user).must_equal true
    end
  end

  describe '#can_follow_collection?' do
    before do
      user.followed_collection_ids << collection.id
      user.save
    end

    it 'should return false' do
      user.can_follow_collection?(collection).must_equal false
    end

    it 'should return true' do
      user.can_follow_collection?(collection1).must_equal true
    end
  end

  describe '#follow_collection' do
    before do
      user.followed_collection_ids << collection.id
      user.save
    end

    it 'should return false' do
      user.follow_collection(collection).must_equal false
    end

    it 'should return true' do
      user.followed_collection_ids.count.must_equal 1
      user.follow_collection(collection1).must_equal true
      user.reload.followed_collection_ids.count.must_equal 2
    end
  end

  describe '#unfollow_collection' do
    before do
      user.followed_collection_ids << collection.id
      user.save
    end

    it 'should return true' do
      user.followed_collection_ids.count.must_equal 1
      user.unfollow_collection(collection).must_equal true
      user.reload.followed_collection_ids.count.must_equal 0
    end
  end

  describe '#spotted_on?' do
    it 'should return true' do
      font.user.spotted_on?(font.photo).must_equal true
    end

    it 'should return false' do
      user.spotted_on?(photo).must_equal false
    end
  end

  describe '#spotted_font' do
    it 'should return the spotted font of the provided photo' do
      font.user.spotted_font(font.photo).must_equal font
    end

    it 'should be nil if no font is font' do
      user.spotted_font(photo).must_be_nil
    end
  end

  describe '#recent_photos' do
    it 'should return its recent photos' do
      photo.user.send(:recent_photos).must_include photo
    end
  end
end
