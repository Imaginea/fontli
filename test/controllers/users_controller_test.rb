require 'test_helper'

describe UsersController do
  let(:user) { create(:user) }

  before do
    create(:user, username: 'fontli')
    @controller.stubs(:admin_required).returns(true)
  end

  describe '#show' do
    let(:photo) { create(:photo, user: user, created_at: Time.now.utc) }
    before do
      photo
      get :show, id: user.id
    end

    it 'should assign user' do
      assigns(:user).must_equal user
    end

    it 'should assigns photos' do
      assigns(:photos).must_include photo
    end
  end

  describe '#add_photo' do
    before do
      xhr :get, :add_photo, id: user.id
    end

    it 'should build a new record' do
      assigns(:photo).new_record?.must_equal true
    end
  end

  describe '#create_photo' do
    let(:data) do
      ActionDispatch::Http::UploadedFile.new(filename: 'image.jpg',
                                             type: 'image/jpeg',
                                             tempfile: File.new(Rails.root + 'test/factories/files/image.jpg'))
    end

    context 'with photo data' do
      before do
        post :create_photo, photo: { data: data }, id: user.id
      end

      it 'should create a user photo' do
        assigns(:user).photos.count.must_equal 1
      end

      it 'should return a success message' do
        request.flash[:notice].must_equal 'Photo uploaded successfully'
      end
    end

    context 'with photo data and collection_names' do
      before do
        post :create_photo, photo: { data: data, collection_names: 'Monogram, Illustration' }, id: user.id
      end

      it 'should create a user photo' do
        assigns(:user).photos.count.must_equal 1
      end

      it 'should add tags for the new photo' do
        assigns(:user).photos.last.collections.count.must_equal 2
      end

      it 'should return a success message' do
        request.flash[:notice].must_equal 'Photo uploaded successfully'
      end
    end

    context 'without photo data' do
      before do
        post :create_photo, photo: { caption: Faker::Lorem.word }, id: user.id
      end

      it 'should return a failure message' do
        request.flash[:alert].must_equal "Filename can't be blank"
      end
    end
  end
end
