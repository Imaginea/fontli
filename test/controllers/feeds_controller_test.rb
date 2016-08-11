require 'test_helper'

describe FeedsController do
  let(:user)              { create(:user) }
  let(:photo)             { create(:photo, :with_caption, user: user, created_at: Time.now.utc) }
  let(:sos_approved)      { create(:photo, font_help: true, sos_approved: true, created_at: Time.now.utc) }
  let(:font)              { create(:font, photo: photo, family_name: Faker::Lorem.word) }
  let(:other_user)        { create(:user) }
  let(:unpublished_photo) { create(:photo, user: user, caption: Photo::DEFAULT_TITLE) }

  before do
    @controller.session[:user_id] = user.id
  end

  describe '#index' do
    before do
      photo
      get :index
    end

    it 'should return JSON' do
      assigns(:photos).must_include photo
    end

    it 'should render index template' do
      assert_template :index
    end
  end

  describe '#show' do
    before do
      create(:like, photo: photo)
      get :show, id: photo.id
    end

    it 'should render show template' do
      assert_template :show
    end

    it 'should assign photo' do
      assigns(:photo).must_equal photo
    end
  end

  describe '#permalink' do
    context 'with invalid permalink' do
      before do
        get :permalink, url: Faker::Internet.url
      end

      it 'should return status 404' do
        response.code.must_equal '404'
      end
    end

    context 'with valid permalink' do
      before do
        get :permalink, url: photo.perma
      end

      it 'should render show template' do
        assert_template 'show'
      end

      it 'should assign photo' do
        assigns(:photo).must_equal photo
      end

      it 'should return status 200' do
        response.code.must_equal '200'
      end
    end
  end

  describe '#sos' do
    before do
      sos_approved

      get :sos
    end

    it 'should assign sos photos' do
      assigns(:photos).must_include sos_approved
    end

    it 'should render sos template' do
      assert_template :sos
    end
  end

  describe '#fonts' do
    before do
      font
      get :fonts, id: photo.id
    end

    it 'should assign fonts' do
      assigns(:fonts).must_include font
    end

    it 'should render partial' do
      assert_template partial: 'feeds/_spotted_pop'
    end
  end

  describe '#recent_fonts' do
    before do
      font
      get :recent_fonts
    end

    it 'should assign fonts' do
      assigns(:fonts).must_include font
    end

    it 'should render template' do
      assert_template :recent_fonts
    end
  end

  describe '#show_font' do
    context 'without params type' do
      before do
        get :show_font, font_id: font.id, family_id: font.family_id
      end

      it 'should assign font' do
        assigns(:font).must_equal font
      end

      it 'should assign photos' do
        assigns(:photos).must_include photo
      end

      it 'should render template' do
        assert_template :show_font
      end
    end

    context 'with params type' do
      let(:fav_font) { create(:fav_font, font: font) }

      before do
        fav_font
        xhr :get, :show_font, font_id: font.id, type: 'fav', family_id: font.family_id
      end

      it 'should assign font' do
        assigns(:font).must_equal font
      end

      it 'should assign users' do
        assigns(:users).must_include fav_font.user
      end

      it 'should render template' do
        assert_template :show_font
      end
    end
  end

  describe '#profile' do
    context 'without params type' do
      before do
        photo
        get :profile, user_id: user.id
      end

      it 'should assign recent photos' do
        assigns(:photos).must_include photo
      end

      it 'should render template' do
        assert_template :profile
      end
    end

    context 'with params type' do
      before do
        create(:follow, user: user, follower: other_user)
        create(:fav_font, font: font, user: user)
        create(:like, photo: photo, user: other_user)
      end

      it 'should assign like' do
        xhr :get, :profile, user_id: other_user.id, type: 'like'
        assigns(:photos).must_include photo
      end

      it 'should assign fav fonts' do
        xhr :get, :profile, user_id: user.id, type: 'fav_font'
        assigns(:fonts).must_include font
      end

      it 'should assign spotted photos' do
        xhr :get, :profile, user_id: font.user_id, type: 'spotted'
        assigns(:photos).must_include font.photo
      end

      it 'should assign user followers' do
        xhr :get, :profile, user_id: other_user.id, type: 'followers'
        assigns(:users).must_include user
      end

      it 'should assign user friends' do
        xhr :get, :profile, user_id: user.id, type: 'follows'
        assigns(:users).must_include other_user
      end
    end
  end

  describe '#popular' do
    context 'with post as params type' do
      before do
        create_list(:like, 2, photo: photo)
        photo.reload
      end

      it 'should return popular photos' do
        get :popular, type: 'post'
        assigns(:photos).must_include photo
      end
    end

    context 'with font as params type' do
      before do
        create_list(:agree, 3, font: font)
        font.reload
      end

      it 'should return recent font having 2 agrees_count' do
        get :popular, type: 'font'
        assigns(:fonts).must_include font
      end
    end

    context 'without params type' do
      before do
        create_list(:photo, 5, user: other_user, created_at: Time.now.utc)
      end

      it 'should return recommended user' do
        get :popular
        assigns(:users).must_include other_user
      end
    end
  end

  describe '#post_feed' do
    let(:photo_data) { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/everlast.jpg', 'image/jpeg') }

    before do
      post :post_feed, photo: photo_data
    end

    it 'should create a feed' do
      assigns(:photo).data_filename.must_equal 'everlast.jpg'
    end

    it 'should redirect to feed page' do
      assert_redirected_to action: :index, photo_id: assigns(:photo).id
    end
  end

  describe '#publish_feed' do
    before do
      post :publish_feed, id: unpublished_photo.id,
                          caption: Faker::Lorem.characters(5),
                          crop: { crop_x: '1', crop_y: '2', crop_w: '3', crop_h: '4' }
    end

    it 'should publish a feed' do
      assigns(:photo).caption.wont_equal Photo::DEFAULT_TITLE
    end

    it 'should redirect to feeds page' do
      assert_redirected_to feeds_path
    end

    it 'should return a success message' do
      request.flash[:notice].must_equal 'Posted to feed, successfully.'
    end
  end

  describe '#socialize_feed' do
    context 'with like as params modal' do
      it 'should add a photo like' do
        assert_difference 'Like.count', 1 do
          xhr :post, :socialize_feed, id: photo.id, modal: 'like'
        end
      end

      it 'should render template' do
        xhr :post, :socialize_feed, id: photo.id, modal: 'like'
        assert_template :like_feed
      end
    end

    context 'with unlike as params modal' do
      before do
        create(:like, photo: photo, user: user)
      end

      it 'should remove a photo like' do
        photo.reload.likes_count.must_equal 1
        xhr :post, :socialize_feed, id: photo.id, modal: 'unlike'
        assigns(:photo).likes_count.must_equal 0
      end
    end

    context 'with comment as params modal' do
      it 'should add a comment on the photo' do
        photo.comments_count.must_equal 0
        xhr :post, :socialize_feed, id: photo.id, modal: 'comment', comment: Faker::Lorem.word
        assigns(:photo).comments_count.must_equal 1
      end
    end

    context 'with flag as params modal' do
      it 'should add a flag on the photo' do
        photo.flags_count.must_equal 0
        xhr :post, :socialize_feed, id: photo.id, modal: 'flag'
        assigns(:photo).flags_count.must_equal 1
      end
    end

    context 'with unflag as params modal' do
      before do
        create(:flag, photo: photo, user: user)
      end

      it 'should remove a flag on the photo' do
        photo.reload.flags_count.must_equal 1
        xhr :post, :socialize_feed, id: photo.id, modal: 'unflag', comment: Faker::Lorem.word
        assigns(:photo).flags_count.must_equal 0
      end
    end

    context 'with remove as params modal' do
      it 'should delete the photo' do
        proc { xhr :post, :socialize_feed, id: photo.id, modal: 'remove' }.must_raise Mongoid::Errors::DocumentNotFound
      end
    end

    context 'with unexpected feed as params modal' do
      it 'should raise StandardError with a message' do
        exception = proc do
          xhr :post, :socialize_feed, id: photo.id, modal: 'unexpected_feed'
        end.must_raise StandardError
        exception.message.must_equal 'unexpected feed: unexpected_feed'
      end
    end
  end

  describe '#follow_user' do
    it 'should unfollow a user' do
      assert_difference 'Follow.count', 1 do
        xhr :post, :follow_user, id: other_user.id
      end
    end

    it 'should render template' do
      xhr :post, :follow_user, id: other_user.id
      assert_template :follow_user
    end
  end

  describe '#unfollow_user' do
    before do
      create(:follow, user: user, follower: other_user)
    end

    it 'should unfollow a user' do
      user.follows.count.must_equal 1
      xhr :post, :unfollow_user, id: other_user.id
      user.reload.follows.count.must_equal 0
    end

    it 'should render template' do
      xhr :post, :unfollow_user, id: other_user.id
      assert_template :follow_user
    end
  end

  describe '#detail_view' do
    it 'should assign foto' do
      get :detail_view, id: photo.id
      assigns(:foto).must_equal photo
    end
  end

  describe '#get_mentions_list' do
    before do
      create(:comment, photo: photo, user: other_user)
    end

    it 'should fail' do
      proc { get :get_mentions_list, id: photo.id }.must_raise ActionView::MissingTemplate
    end
  end

  describe '#search_autocomplete' do
    context 'with username in params term' do
      before do
        get :search_autocomplete, term: user.username
      end

      it 'should return JSON' do
        parsed_result = JSON.parse(response.body)
        parsed_result.must_include user.username
      end
    end

    context 'with caption in params term' do
      before do
        get :search_autocomplete, term: photo.caption
      end

      it 'should return JSON' do
        parsed_result = JSON.parse(response.body)
        parsed_result.must_include photo.caption
      end
    end

    context 'with family_name in params term' do
      before do
        get :search_autocomplete, term: font.family_name
      end

      it 'should return JSON' do
        parsed_result = JSON.parse(response.body)
        parsed_result.must_include font.family_name
      end
    end
  end

  describe '#search' do
    context 'with username in params search' do
      before do
        get :search, search: user.username
      end

      it 'should assign users' do
        assigns(:users).must_include user
      end

      it 'should not assign posts' do
        assigns(:posts).must_be_empty
      end

      it 'should not assign fonts' do
        assigns(:fonts).must_be_empty
      end
    end

    context 'with caption in params search' do
      before do
        get :search, search: photo.caption
      end

      it 'should not assign users' do
        assigns(:users).must_be_empty
      end

      it 'should assign posts' do
        assigns(:posts).must_include photo
      end

      it 'should not assign fonts' do
        assigns(:fonts).must_be_empty
      end
    end

    context 'with family_name in params search' do
      before do
        get :search, search: font.family_name
      end

      it 'should not assign users' do
        assigns(:users).must_be_empty
      end

      it 'should assign posts' do
        assigns(:posts).must_be_empty
      end

      it 'should not assign fonts' do
        assigns(:fonts).must_include font
      end
    end
  end
end
