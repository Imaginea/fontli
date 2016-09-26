require 'test_helper'

describe AdminController do
  let(:user)          { create(:user) }
  let(:user1)         { create(:user, :with_fullname) }
  let(:photo)         do
    create(:photo, show_in_homepage: true, created_at: Time.now.utc,
                   address: Faker::Address.city)
  end
  let(:stat)          { create(:stat) }
  let(:inactive_user) { create(:user, active: false) }
  let(:collection)    { create(:collection) }
  let(:other_user)    { create(:user) }
  let(:other_photo)   { create(:photo, :with_caption, user: photo.user, created_at: Time.now.utc) }
  let(:sos_requested) { create(:photo, font_help: true, created_at: Time.now.utc) }
  let(:sos_approved)  { create(:photo, font_help: true, sos_approved: true, created_at: Time.now.utc) }

  before do
    @controller.stubs(:admin_required).returns(true)
  end

  describe '#index' do
    before do
      user
      photo
      stat
      get :index
    end

    it 'should assign admin presenter' do
      assigns(:admin_presenter).must_be_instance_of AdminPresenter
    end

    it 'should render template index' do
      assert_template :index
    end
  end

  describe '#users' do
    before do
      user
      user1
    end

    it 'should assign user' do
      get :users
      assigns(:users).must_include user
    end

    context 'with search params' do
      it 'should assigns users with the one having the provided username' do
        get :users, search: user.username
        assigns(:users).must_include user
      end

      it 'should assigns users with the one having the provided full_name' do
        get :users, search: user1.full_name
        assigns(:users).must_include user1
      end
    end
  end

  describe '#suspend_user' do
    before do
      put :suspend_user, id: user.id
    end

    it 'should make the user inactive' do
      assigns(:res).must_equal true
      user.reload.active.must_equal false
    end

    it 'should redirect to admin users page' do
      assert_redirected_to '/admin/users'
    end
  end

  describe '#delete_user' do
    before do
      delete :delete_user, id: user.id
    end

    it 'should delete a user' do
      assigns(:res).must_equal true
      User.count.must_equal 0
    end

    it 'should redirect to admin users page' do
      assert_redirected_to '/admin/users'
    end
  end

  describe '#suspended_users' do
    before do
      inactive_user
      get :suspended_users
    end

    it 'should return all the suspended users' do
      assigns(:users).must_include inactive_user
    end

    it 'should render users page' do
      assert_template :users
    end
  end

  describe '#activate_user' do
    before do
      put :activate_user, id: inactive_user.id
    end

    it 'should activate a user' do
      assigns(:res).must_equal true
      inactive_user.reload.active.must_equal true
    end

    it 'should redirect to admin users page' do
      assert_redirected_to '/admin/users'
    end
  end

  describe '#photos' do
    before do
      photo
      other_photo
    end

    context 'with params' do
      it 'should return a photo having provided caption' do
        get :photos, search: other_photo.caption
        assigns(:fotos).must_include other_photo
      end

      it 'should return a photo having provided user_id' do
        get :photos, user_id: photo.user_id
        assigns(:fotos).must_include other_photo
        assigns(:fotos).must_include photo
      end

      it 'should return homepage photos' do
        get :photos, home: true
        assigns(:title).must_equal 'Homepage Photos'
        assigns(:fotos).must_include photo
      end
    end

    context 'without params' do
      before do
        get :photos
      end

      it 'should return all photos' do
        assigns(:fotos).must_include other_photo
        assigns(:fotos).must_include photo
      end
    end
  end

  describe '#flagged_users' do
    before do
      create_list(:user_flag, 4, user: other_user)
      get :flagged_users
    end

    it 'should include users having flags count greater than 3' do
      assigns(:users).must_include other_user
    end

    it 'should not include users having flags count less than 3' do
      assigns(:users).wont_include user
    end

    it 'should render users template' do
      assert_template :users
    end
  end

  describe '#unflag_user' do
    before do
      create_list(:user_flag, 4, user: other_user)
      put :unflag_user, id: other_user.id
    end

    it 'should destroy the user flags' do
      other_user.user_flags.count.must_equal 0
    end

    it 'should return a success message' do
      request.flash[:notice].must_equal 'User account unflagged.'
    end

    it 'should redirect to admin flagged_users page' do
      assert_redirected_to '/admin/flagged_users'
    end
  end

  describe '#flagged_photos' do
    before do
      create_list(:flag, 6, photo: other_photo)
      get :flagged_photos
    end

    it 'should include photos having flags count greater than 5' do
      assigns(:fotos).must_include other_photo
    end

    it 'should not include photos having flags count less than 5' do
      assigns(:fotos).wont_include photo
    end

    it 'should render photos page' do
      assert_template :photos
    end
  end

  describe '#unflag_photo' do
    before do
      create_list(:flag, 4, photo: other_photo)
      xhr :put, :unflag_photo, id: other_photo.id
      other_photo.reload
    end

    it 'should destroy the photo flags' do
      other_photo.flags.count.must_equal 0
    end

    it 'should reset the flags_count' do
      other_photo.flags_count.must_equal 0
    end
  end

  describe '#sos' do
    before do
      sos_requested
      sos_approved
    end

    context 'with params' do
      let(:sos_requested1) { create(:photo, :with_caption, font_help: true, created_at: Time.now.utc) }
      let(:sos_approved1)  { create(:photo, :with_caption, font_help: true, sos_approved: true, created_at: Time.now.utc) }

      it 'should include requested sos' do
        get :sos, req: 'true'
        assigns(:title).must_equal 'SoS photos waiting for approval'
        assigns(:fotos).must_include sos_requested
      end

      it 'should include approved sos having the given caption' do
        get :sos, search: sos_approved1.caption
        assigns(:fotos).must_include sos_approved1
      end

      it 'should include requested sos having the given caption' do
        get :sos, req: 'true', search: sos_requested1.caption
        assigns(:fotos).must_include sos_requested1
      end

      it 'should not include non-sos photos having the given caption' do
        get :sos, search: other_photo.caption
        assigns(:fotos).wont_include other_photo
      end
    end

    context 'without params' do
      it 'should return sos approved' do
        get :sos
        assigns(:fotos).must_include sos_approved
      end
    end

    it 'should render photos page' do
      get :sos
      assert_template :photos
    end
  end

  describe '#approve_sos' do
    before do
      xhr :put, :approve_sos, photo_id: sos_requested.id
    end

    it 'should approve a requested sos' do
      assigns(:res).must_equal true
    end
  end

  describe '#delete_photo' do
    before do
      xhr :put, :delete_photo, id: photo.id
    end

    it 'should delete a photo' do
      assigns(:res).must_equal true
    end
  end

  describe '#select_photo' do
    it 'should select a photo for homepage' do
      xhr :put, :select_photo, id: other_photo.id
      assigns(:res).must_equal true
      other_photo.reload.show_in_homepage.must_equal true
    end

    it 'should remove a photo from homepage' do
      xhr :put, :select_photo, id: photo.id, select: 'false'
      assigns(:res).must_equal true
      photo.reload.show_in_homepage.must_equal false
    end
  end

  describe '#popular_users' do
    before do
      create_list(:photo, 5, user: user, created_at: Time.now.utc)
      get :popular_users
    end

    it 'should include popular users having minimum 5 posts' do
      assigns(:users).must_include user
    end
  end

  describe '#popular_photos' do
    before do
      create_list(:like, 2, photo: photo)
      get :popular_photos
    end

    it 'should include popular photos having minimum 2 likes' do
      assigns(:photos).must_include photo
    end
  end

  describe '#popular_fonts' do
    let(:font) { create(:font, photo: other_photo) }

    before do
      create_list(:agree, 3, font: font)
      get :popular_fonts
    end

    it 'should return popular tagged photos of the fonts' do
      assigns(:photos).must_include other_photo
    end

    it 'should render popular photos page' do
      assert_template 'popular_photos'
    end
  end

  describe '#select_for_header' do
    it 'show update show_in_header of user' do
      put :select_for_header, modal: 'User', id: user.id, status: 'true'
      user.reload.show_in_header.must_equal true
      response.body.must_equal ' '
    end

    it 'show update show_in_header of photo' do
      put :select_for_header, modal: 'Photo', id: photo.id, status: 'true'
      photo.reload.show_in_header.must_equal true
      response.body.must_equal ' '
    end

    context 'with non-existing class name as params modal' do
      it 'should raise StandardError with a message' do
        exception = proc do
          put :select_for_header, modal: 'NonExistingClass', id: photo.id, status: 'true'
        end.must_raise StandardError
        exception.message.must_equal 'unexpected request!'
      end
    end
  end

  describe '#expire_popular_cache' do
    before do
      request.env['HTTP_REFERER'] = 'http://test.host/admin/popular_photos'
      post :expire_popular_cache
    end

    it 'should delete popular_users cache' do
      Rails.cache.fetch('popular_users').must_be_nil
    end

    it 'should delete popular photos cache' do
      Rails.cache.fetch('popular_photos').must_be_nil
    end

    it 'should delete popular fonts cache' do
      Rails.cache.fetch('popular_fonts').must_be_nil
    end

    it 'should delete recent fonts cache' do
      Rails.cache.fetch('recent_fonts').must_be_nil
    end

    it 'should delete recent fonts foto_ids cache' do
      Rails.cache.fetch('recent_fonts_foto_ids_map').must_be_nil
    end

    it 'should redirect to back' do
      assert_redirected_to request.env['HTTP_REFERER']
    end
  end

  describe '#update_stat' do
    before do
      create(:stat)
      put :update_stat, version: '2.2'
    end

    it 'should update app version' do
      Stat.current.app_version.must_equal '2.2'
    end

    it 'should render index page' do
      assert_redirected_to action: :index
    end
  end

  describe 'send_push_notifications' do
    before do
      APN.stubs(:notify_async).returns(true)
      create(:user, iphone_token: SecureRandom.hex(3))
    end

    it 'should return alert message if no message is provided' do
      post :send_push_notifications
      request.flash[:alert].must_equal 'Message can\'t be blank'
    end

    it 'should send push notification to users' do
      post :send_push_notifications, message: 'Push Notification'
      request.flash[:notice].must_equal 'Notified 1 users.'
    end

    it 'should redirect to admin page' do
      post :send_push_notifications, message: 'Push Notification'
      assert_redirected_to '/admin'
    end
  end

  describe '#user_stats' do
    let(:email_user)   { create(:user, platform: nil, created_at: Date.parse('12-09-2014')) }
    let(:email_user1)  { create(:user, platform: nil, created_at: Date.parse('12-10-2014')) }
    let(:fb_user)      { create(:user, :with_platform, platform: 'facebook') }
    let(:twitter_user) { create(:user, :with_platform, platform: 'twitter') }

    before do
      email_user
      email_user1
      fb_user
      twitter_user
    end

    it 'should return facebook users statistics' do
      get :user_stats, platform: 'facebook'
      parsed_result = JSON.parse(response.body)
      parsed_result[fb_user.created_at.strftime('%Y')]['data'].wont_be_empty
    end

    it 'should return twitter users statistics' do
      get :user_stats, platform: 'twitter'
      parsed_result = JSON.parse(response.body)
      parsed_result[twitter_user.created_at.strftime('%Y')]['data'].wont_be_empty
    end

    it 'should return email users statistics' do
      get :user_stats, platform: 'email'
      parsed_result = JSON.parse(response.body)
      parsed_result.values.first['data'].wont_be_empty
      parsed_result.values.first['total_count'].wont_be_nil
    end
  end

  describe '#top_contributors' do
    before do
      user
      user1
      photo
      create(:photo, user: user1)
    end

    it 'should assign users with the user having photos' do
      get :top_contributors
      assigns(:top_contributors).wont_include user
      assigns(:top_contributors).must_include photo.user
    end

    context 'with search params' do
      it 'should assigns users with the one having the provided username and photos' do
        get :top_contributors, search: user1.username
        assigns(:top_contributors).must_include user1
      end

      it 'should assigns users with the one having the provided full_name and photos' do
        get :top_contributors, search: user1.full_name
        assigns(:top_contributors).must_include user1
      end
    end

    context 'with csv format' do
      it 'should return a csv data' do
        get :top_contributors, format: :csv
        response.body.wont_be_empty
      end
    end
  end
end
