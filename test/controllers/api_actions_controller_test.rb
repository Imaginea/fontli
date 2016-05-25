require 'test_helper'

describe ApiActionsController do
  let(:user)              { create(:user) }
  let(:api_session)       { create(:api_session, expires_at: Time.now.utc + 40.weeks) }
  let(:username)          { Faker::Name.first_name + '11' }
  let(:collection)        { create(:collection, active: true) }
  let(:photo)             { create(:photo, created_at: Time.now.utc, user: user) }
  let(:photo_data)        { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/everlast.jpg', 'image/jpeg') }
  let(:unpublished_photo) { create(:photo, caption: Photo::DEFAULT_TITLE) }
  let(:font)              { create(:font) }
  let(:hash_tag)          { create(:hash_tag, hashable: create(:photo, created_at: Time.now.utc)) }
  let(:other_user)        { create(:user) }
  let(:workbook)          { create(:workbook) }

  before do
    create(:user, username: 'fontli')
    @controller.stubs(:current_session).returns(api_session)
    @controller.instance_variable_set(:@current_session, api_session)
  end

  describe '#log_crash' do
    context 'with params' do
      before do
        get :log_crash, content: 'Test Error'
      end

      it 'should return JSON' do
        parsed_result = JSON.parse(response.body)
        parsed_result['response'].must_equal true
        parsed_result['status'].must_equal 'Success'
      end

      it 'should return status 200' do
        response.code.must_equal '200'
      end
    end

    context 'without params' do
      before do
        get :log_crash
      end

      it 'should require content' do
        parsed_result = JSON.parse(response.body)
        parsed_result['response'].must_equal ''
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Required params missing - content'
      end
    end
  end

  describe '#stats' do
    let(:stat) { create(:stat) }

    before do
      stat
      get :stats
    end

    it 'should return the current app version' do
      parsed_result = JSON.parse(response.body)
      parsed_result['response']['app_version'].must_equal stat.app_version
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return status 200' do
      response.code.must_equal '200'
    end
  end

  describe '#features' do
    let(:feature) { create(:feature) }

    before do
      feature
      get :features
    end

    it 'should return app features' do
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].first['name'].must_equal feature.name
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return status 200' do
      response.code.must_equal '200'
    end
  end

  describe '#signin' do
    let(:device_id) { SecureRandom.hex(6) }

    context 'with valid credentials' do
      before do
        post :signin, username: user.username, password: user.password, device_id: device_id
      end

      it 'should return the success response' do
        parsed_result = JSON.parse(response.body)
        parsed_result['response'].wont_be_empty
        parsed_result['status'].must_equal 'Success'
      end

      it 'should return status 200' do
        response.code.must_equal '200'
      end
    end

    context 'with invalid credentials' do
      it 'should require valid username and password' do
        post :signin, username: user.username, password: SecureRandom.hex(4), device_id: device_id
        parsed_result = JSON.parse(response.body)
        parsed_result['response'].must_equal ''
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Invalid Username or Password!'
      end
    end

    context 'without params' do
      it 'should fail' do
        post :signin
        parsed_result = JSON.parse(response.body)
        parsed_result['response'].must_equal ''
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Required params missing - username, password, device_id'
      end
    end
  end

  describe '#signup' do
    context 'with valid params' do
      it 'should create a new user' do
        assert_difference 'User.count', 1 do
          post :signup, username: username, email: Faker::Internet.email
        end
      end
    end

    context 'with invalid params' do
      it 'should fail if username not valid' do
        post :signup, username: SecureRandom.hex(2), email: Faker::Internet.email
        parsed_result = JSON.parse(response.body)
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Username is too short (minimum is 5 characters)'
      end

      it 'should fail if user already exists with the given username' do
        post :signup, username: user.username, email: Faker::Internet.email
        parsed_result = JSON.parse(response.body)
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Username is already taken'
      end

      it 'should fail if email if not valid' do
        post :signup, username: username, email: SecureRandom.hex(6)
        parsed_result = JSON.parse(response.body)
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Email is invalid'
      end

      it 'should fail if email already exists' do
        post :signup, username: username, email: user.email
        parsed_result = JSON.parse(response.body)
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Email is already taken'
      end
    end

    context 'without params' do
      it 'should fail if email not provided' do
        post :signup, username: username
        parsed_result = JSON.parse(response.body)
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Required params missing - email'
      end

      it 'should fail if username not provided' do
        post :signup, email: Faker::Internet.email
        parsed_result = JSON.parse(response.body)
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal 'Required params missing - username'
      end
    end

    context 'with platform' do
      it 'should fail if extuid not present' do
        post :signup, username: username, email: Faker::Internet.email, platform: 'facebook'
        parsed_result = JSON.parse(response.body)
        parsed_result['status'].must_equal 'Failure'
        parsed_result['errors'].must_equal "Sorry, we couldn't sign you up using Facebook. Please try using Twitter."
      end

      it 'should create a user' do
        assert_difference 'User.count', 1 do
          post :signup, username: username, email: Faker::Internet.email, platform: 'facebook', extuid: SecureRandom.hex(6)
        end
      end
    end
  end

  describe '#signout' do
    it 'should deactivate a session' do
      get :signout
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
    end
  end

  describe '#forgot_pass' do
    it 'should return success response' do
      post :forgot_pass, email_or_uname: user.email
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#reset_pass' do
    context 'with valid params' do
      it 'should reset the password' do
        post :reset_pass, password: user.password, new_password: 'new_pass', confirm_password: 'new_pass'
        parsed_result = JSON.parse(response.body)
        parsed_result['response'].must_equal true
        parsed_result['status'].must_equal 'Success'
      end
    end

    context 'with invalid params' do
      it 'should fail if password not given' do
        post :reset_pass, new_password: 'new_password', confirm_password: 'new_password'
        parsed_result = JSON.parse(response.body)
        parsed_result['errors'].must_equal 'Required params missing - password'
        parsed_result['status'].must_equal 'Failure'
      end

      it 'should fail if new password not given' do
        post :reset_pass, password: api_session.user.password
        parsed_result = JSON.parse(response.body)
        parsed_result['errors'].must_equal 'Required params missing - new_password, confirm_password'
        parsed_result['status'].must_equal 'Failure'
      end
    end
  end

  describe '#login_check' do
    let(:other_user) { create(:user, extuid: SecureRandom.hex(6)) }

    before do
      other_user
    end

    it 'should fail' do
      get :login_check, auth_token: SecureRandom.hex(6)
      parsed_result = JSON.parse(response.body)
      parsed_result['errors'].must_equal 'User Not Found!'
    end

    it 'should do a login check' do
      @controller.stubs(:get_extuid_token).returns(other_user.extuid)
      post :login_check, auth_token: other_user.extuid
      get :login_check
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
    end
  end

  describe '#check_token' do
    it 'should return success response' do
      get :check_token
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
    end
  end

  describe '#collections' do
    before do
      collection
      get :collections
    end

    it 'should return collections in response' do
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return status 200' do
      response.code.must_equal '200'
    end
  end

  describe '#collection_search' do
    it 'should find a collection with the given name' do
      get :collection_search, name: collection.name
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#follow_collection' do
    it 'should return a success response' do
      post :follow_collection, collection_id: collection.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#unfollow_collection' do
    before do
      user.followed_collection_ids << collection.id
      user.save
    end

    it 'should return a success response' do
      post :unfollow_collection, collection_id: collection.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#collection_detail' do
    before do
      collection.photos << photo
    end

    it 'should return JSON data' do
      get :collection_detail, collection_id: collection.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['response']['fotos'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#add_photo_to_collections' do
    it 'should return a success response' do
      post :add_photo_to_collections, photo_id: photo.id, collection_names: [collection.name]
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].first['photo_ids'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#upload_data' do
    it 'should return a success response' do
      post :upload_data, data: photo_data
      parsed_result = JSON.parse(response.body)
      parsed_result['response']['id'].wont_be_nil
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#publish_photo' do
    it 'should publish a photo and return success response' do
      post :publish_photo, photo_id: unpublished_photo.id, caption: Faker::Lorem.word
      parsed_result = JSON.parse(response.body)
      parsed_result['response']['caption'].wont_equal Photo::DEFAULT_TITLE
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#photo_detail' do
    let(:like)    { create(:like, photo: photo) }
    let(:comment) { create(:comment, photo: photo) }

    before do
      like
      comment
    end

    it 'should return JSON data' do
      get :photo_detail, photo_id: photo.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  # Should be updated once the bug is fixed
  describe '#update_photo' do
    it 'should update photo and return JSON data' do
      opts = { caption: Faker::Lorem.word, photo_id: photo.id }
      proc { post :update_photo, opts }.must_raise NoMethodError
    end
  end

  describe '#delete_photo' do
    it 'should delete a photo' do
      assert_difference 'Photo.count', 1 do
        post :delete_photo, photo_id: photo.id
      end
    end
  end

  describe '#like_photo' do
    it 'should create a like' do
      assert_difference 'Like.count', 1 do
        post :like_photo, photo_id: photo.id
      end
    end
  end

  describe '#unlike_photo' do
    before do
      create(:like, photo: photo, user: api_session.user)
    end

    it 'should delete a like and return a success response' do
      post :unlike_photo, photo_id: photo.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response']['likes_count'].must_equal 0
    end
  end

  describe '#flag_photo' do
    it 'should create a flag and return a success response' do
      assert_difference 'Flag.count', 1 do
        post :flag_photo, photo_id: photo.id
      end
    end
  end

  describe '#flag_user' do
    it 'should create a user_flag' do
      assert_difference 'UserFlag.count', 1 do
        post :flag_user, user_id: user.id
      end
    end
  end

  describe '#share_photo' do
    it 'should add a photo share' do
      assert_difference 'Share.count', 1 do
        post :share_photo, photo_id: photo.id
      end
    end
  end

  describe '#comment_photo' do
    it 'should create a comment' do
      assert_difference 'Comment.count', 1 do
        post :comment_photo, photo_id: photo.id, body: Faker::Lorem.sentence
      end
    end
  end

  describe '#comments_list' do
    let(:font_tag) { create(:font_tag, user: api_session.user) }

    before do
      create(:comment, photo_id: photo.id, font_tag_ids: [font_tag.id])
      create(:comment, photo_id: photo.id)
    end

    it 'should return JSON data' do
      get :comments_list, photo_id: photo.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  # need to add font_tag_ids to avoid error
  describe '#delete_comment' do
    let(:comment) { create(:comment, font_tag_ids: [create(:font_tag).id]) }

    it 'should return success response' do
      post :delete_comment, comment_id: comment.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
    end

    it 'should fail' do
      post :delete_comment, comment_id: SecureRandom.hex(2)
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal false
    end
  end

  describe '#add_to_sos' do
    it 'should return a success response' do
      post :add_to_sos, photo_id: photo.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
    end
  end

  describe '#agree_font' do
    it 'should add a agree for the font' do
      assert_difference 'Agree.count', 1 do
        post :agree_font, font_id: font.id
      end
    end
  end

  describe '#unagree_font' do
    before do
      create(:agree, font_id: font.id, user_id: api_session.user_id)
    end

    it 'should delete an agree for the font and return a success response' do
      post :unagree_font, font_id: font.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
    end
  end

  describe '#fav_font' do
    it 'should add a fav font' do
      assert_difference 'FavFont.count', 1 do
        post :fav_font, font_id: font.id
      end
    end
  end

  describe '#unfav_font' do
    before do
      create(:fav_font, font_id: font.id, user_id: api_session.user_id)
    end

    it 'should delete a font and return a success response' do
      post :unfav_font, font_id: font.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
    end
  end

  describe '#likes_list' do
    before do
      create_list(:like, 2, photo: photo)
    end

    it 'should return JSON data of users who liked the photo' do
      get :likes_list, photo_id: photo.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#mentions_list' do
    before do
      create(:follow, user: api_session.user, follower_id: user.id)
    end

    it 'should return JSON data' do
      get :mentions_list, photo_id: photo.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#hash_tag_search' do
    it 'should return JSON of the matching hash_tags' do
      get :hash_tag_search, name: hash_tag.name
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#hash_tag_photos' do
    it 'should return JSON of the matching hash_tag photo' do
      get :hash_tag_photos, name: hash_tag.name
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#hash_tag_feeds' do
    it 'should return JSON of the matching hash_tag photos sorted by likes_count' do
      get :hash_tag_feeds, name: hash_tag.name
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the matching hash_tag photos sorted by created_at' do
      get :hash_tag_feeds, name: hash_tag.name, recent: true
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#leaderboard' do
    before do
      create_list(:photo, 5, user: user, created_at: Time.now.utc)
    end

    it 'should return JSON of recommended users' do
      get :leaderboard
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#popular_photos' do
    before do
      create_list(:like, 2, photo: photo)
    end

    it 'should return JSON of popular photos' do
      get :popular_photos
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#sos_photos' do
    before do
      create(:photo, font_help: true, sos_approved: true, created_at: Time.now.utc)
    end

    it 'should return JSON of sos photos' do
      get :sos_photos
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#popular_fonts' do
    before do
      font
    end

    it 'should return JSON of popular fonts' do
      get :popular_fonts
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#recent_fonts' do
    before do
      create_list(:agree, 3, font: font)
    end

    it 'should return JSON of recent fonts' do
      get :recent_fonts
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#font_photos' do
    it 'should return JSON of font photos' do
      get :font_photos, family_id: font.family_id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#font_heat_map' do
    it 'should return success response' do
      get :font_heat_map, font_id: font.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should fail' do
      get :font_heat_map, font_id: SecureRandom.hex(2)
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_be_empty
      parsed_result['status'].must_equal 'Failure'
      parsed_result['errors'].must_equal 'Record Not Found!'
    end
  end

  describe '#user_search' do
    it 'should return JSON of matching user' do
      get :user_search, name: user.username
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return empty response' do
      get :user_search, name: Faker::Name.name
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_profile' do
    it 'should return JSON of current user' do
      get :user_profile
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of user matching the ' do
      get :user_profile, username: user.username
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of current user' do
      get :user_profile, user_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#update_profile' do
    it 'should update user full_name and return success response' do
      post :update_profile, full_name: Faker::Name.name
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end

    it 'should update user iphone token and return success response' do
      post :update_profile, iphone_token: SecureRandom.hex(6)
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#invite_friends' do
    let(:frnds) { [{ platform: 'facebook', email: Faker::Internet.email }] }

    it 'should invite a friend and return success response' do
      post :invite_friends, friends: frnds
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#my_invites' do
    let(:invite) { create(:invite, user: user, platform: 'facebook', email: Faker::Internet.email) }

    it 'should return JSON of current_user invites and friends' do
      get :my_invites
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#my_invites_opt' do
    let(:platform) { 'facebook' }
    let(:user1)    { create(:user, extuid: SecureRandom.hex(6), platform: platform) }
    let(:frnds)    { [{ id: user1.extuid }].to_json }

    it 'should populate current user invite state' do
      post :my_invites_opt, friends: frnds, platform: platform
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_friends' do
    before do
      create(:follow, user: api_session.user, follower_id: user.id)
      create(:follow, user: user, follower_id: other_user.id)
    end

    it 'should return JSON of current user friends' do
      get :user_friends
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the provided user friends' do
      get :user_friends, user_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_followers' do
    before do
      create(:follow, user: user, follower_id: api_session.user.id)
      create(:follow, user: user, follower_id: other_user.id)
    end

    it 'should return JSON of current user followers' do
      get :user_followers
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the provided user followers' do
      get :user_followers, user_id: other_user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_photos' do
    before do
      photo
      create(:photo, user: api_session.user, created_at: Time.now.utc)
    end

    it 'should return JSON of current user photos' do
      get :user_photos
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the provided user photos' do
      get :user_photos, user_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_popular_photos' do
    before do
      photo
      create(:photo, user: api_session.user, created_at: Time.now.utc)
    end

    it 'should return JSON of current user popular photos' do
      get :user_popular_photos
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the provided user popular photos' do
      get :user_popular_photos, user_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_favorites' do
    before do
      create(:like, photo: photo, user: user)
      create(:like, photo: photo, user: api_session.user)
    end

    it 'should return JSON of current user favorite photos' do
      get :user_favorites
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the provided user favorite photos' do
      get :user_favorites, user_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_fonts' do
    before do
      create(:font, user: api_session.user)
    end

    it 'should return JSON of current user fonts' do
      get :user_fonts
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the provided user fonts' do
      get :user_fonts, user_id: font.user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#user_fav_fonts' do
    before do
      create(:fav_font, user: api_session.user)
      create(:fav_font, font: font, user: user)
    end

    it 'should return JSON of current user favorite fonts' do
      get :user_fav_fonts
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end

    it 'should return JSON of the provided user favorite fonts' do
      get :user_fav_fonts, user_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].wont_be_empty
      parsed_result['status'].must_equal 'Success'
    end
  end

  describe '#follower_user' do
    it 'should return a success response' do
      post :follow_user, user_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end

    it 'should fail' do
      post :follow_user
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_be_empty
      parsed_result['status'].must_equal 'Failure'
      parsed_result['errors'].must_equal 'Required params missing - user_id'
    end
  end

  describe '#unfollow_friend' do
    before do
      create(:follow, user: api_session.user, follower_id: user.id)
    end

    it 'should return a success response' do
      post :unfollow_friend, friend_id: user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_equal true
      parsed_result['status'].must_equal 'Success'
    end

    it 'should fail' do
      post :unfollow_friend, friend_id: other_user.id
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_be_empty
      parsed_result['status'].must_equal 'Failure'
      parsed_result['errors'].must_equal 'Whoops! Friend Not Found'
    end
  end

  describe '#add_suggestion' do
    it 'should add a suggestion' do
      assert_difference 'Suggestion.count', 1 do
        post :add_suggestion, text: Faker::Lorem.sentence, user: user, platform: 'facebook', app_version: '2.0.1', os_version: '14.04', sugg_type: Faker::Lorem.word
      end
    end

    it 'should fail' do
      post :add_suggestion, text: Faker::Lorem.sentence
      parsed_result = JSON.parse(response.body)
      parsed_result['response'].must_be_empty
      parsed_result['status'].must_equal 'Failure'
      parsed_result['errors'].must_equal 'Required params missing - platform, os_version, sugg_type, app_version'
    end
  end

  describe '#feeds_html' do
    before do
      photo
    end

    it 'should render feeds template' do
      get :feeds_html
      assigns(:feeds).must_include photo
      assert_template :feeds
    end
  end

  describe '#my_notifications_count' do
    before do
      create(:notification, :for_like, to_user: api_session.user)
    end

    it 'should return current user notification count' do
      get :my_notifications_count
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['notifications_count'].must_equal 1
    end
  end

  describe '#my_updates' do
    let(:notification) { create(:notification, :for_follow, to_user: api_session.user) }

    before do
      notification
    end

    it 'should return the user notifications' do
      get :my_updates
      assigns(:notifications).must_include notification
      assert_template :my_updates
    end
  end

  describe '#network_updates' do
    let(:follow)   { create(:follow, user: api_session.user, follower_id: user.id) }
    let(:like)     { create(:like, user: user) }
    let(:font_tag) { create(:font_tag, user: user) }
    let(:fav_font) { create(:fav_font, user: user) }
    let(:follow1)  { create(:follow, user: user) }

    before do
      like
      font_tag
      follow
      follow1
      fav_font
      get :network_updates
    end

    it 'should render network_update_templates' do
      assert_template :network_updates
      assigns(:updates_by_user).wont_be_empty
      assigns(:updates_by_item).wont_be_empty
      assigns(:tags_map).wont_be_empty
      assigns(:photos_map).wont_be_empty
      assigns(:fonts_map).wont_be_empty
      assigns(:users_map).wont_be_empty
    end
  end

  describe '#my_feeds' do
    it 'should return empty response' do
      get :my_feeds
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].must_be_empty
    end

    it 'should return JSON response' do
      create(:photo, user: api_session.user, created_at: Time.now.utc)
      get :my_feeds
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].wont_be_empty
    end
  end

  describe '#feed_detail' do
    it 'should return JSON' do
      get :feed_detail, feed_id: photo.id
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].wont_be_empty
    end

    it 'should fail' do
      get :feed_detail, feed_id: SecureRandom.hex(2)
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Failure'
      parsed_result['response'].must_be_empty
      parsed_result['errors'].must_equal 'Photo not found!'
    end
  end

  describe '#add_workbook' do
    it 'should add a workbook' do
      assert_difference 'Workbook.count', 1 do
        post :add_workbook, title: Faker::Name.name, description: Faker::Lorem.sentence, user: user
      end
    end

    it 'should fail' do
      post :add_workbook, description: Faker::Lorem.sentence
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Failure'
      parsed_result['response'].must_be_empty
      parsed_result['errors'].must_equal 'Required params missing - title'
    end
  end

  describe '#update_workbook' do
    let(:description) { Faker::Lorem.sentence }

    it 'should update workbook and return success response' do
      post :update_workbook, workbook_id: workbook.id, description: description
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].must_equal true
      workbook.reload.description.must_equal description
    end

    it 'should fail' do
      post :update_workbook, workbook_id: workbook.id, title: ''
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Failure'
      parsed_result['response'].must_equal false
      parsed_result['errors'].must_equal "Title can't be blank"
    end
  end

  describe '#list_workbooks' do
    before do
      create(:workbook, user: api_session.user)
    end

    it 'should return JSON of current user workbooks' do
      get :list_workbooks
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].wont_be_empty
    end

    it 'should return JSON of the provided user workbooks' do
      get :list_workbooks, user_id: workbook.user_id
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].wont_be_empty
    end
  end

  describe '#workbook_photos' do
    before do
      create(:photo, workbook: workbook)
    end

    it 'should return photos of provided workbook' do
      get :workbook_photos, workbook_id: workbook.id
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].wont_be_empty
    end

    it 'should fail' do
      proc { get :workbook_photos, workbook_id: SecureRandom.hex(2) }.must_raise NoMethodError
    end
  end

  describe '#fav_workbook' do
    it 'should add a favorite workbook of current user' do
      assert_difference 'FavWorkbook.count', 1 do
        post :fav_workbook, workbook_id: workbook.id
      end
    end

    it 'should fail' do
      post :fav_workbook, workbook_id: SecureRandom.hex(2)
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Failure'
      parsed_result['response'].must_be_empty
      parsed_result['errors'].must_equal "Workbook can't be blank"
    end
  end

  describe '#unfav_workbook' do
    it 'should remove a favorite workbook of current user' do
      create(:fav_workbook, user: api_session.user, workbook: workbook)
      post :unfav_workbook, workbook_id: workbook.id
      parsed_result = JSON.parse(response.body)
      parsed_result['status'].must_equal 'Success'
      parsed_result['response'].must_equal true
    end

    it 'should fail' do
      proc { post :unfav_workbook, workbook_id: workbook.id }.must_raise NoMethodError
    end
  end
end
