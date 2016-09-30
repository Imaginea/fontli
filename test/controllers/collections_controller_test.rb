require 'test_helper'

describe CollectionsController do
  let(:collection) { create(:collection) }

  before do
    @controller.stubs(:admin_required).returns(true)
  end

  describe '#index' do
    before do
      collection
      get :index
    end

    it 'should include all the collections' do
      assigns(:collections).must_include collection
    end
  end

  describe '#create' do
    context 'with valid params' do
      before do
        post :create, collection: { description: Faker::Lorem.sentence, name: Faker::App.name }
      end

      it 'should create a collection' do
        Collection.count.must_equal 1
      end

      it 'should return a success message' do
        request.flash[:notice].must_equal 'Created successfully'
      end

      it 'should redirect to admin collections page' do
        assert_redirected_to '/admin/collections'
      end
    end

    context 'without valid params' do
      before do
        post :create, collection: { description: Faker::Lorem.sentence }
      end

      it 'should create a collection' do
        Collection.count.must_equal 0
      end

      it 'should return a failure message' do
        request.flash[:alert].must_equal "Name can't be blank"
      end
    end
  end

  describe '#activate' do
    context 'valid collection' do
      before do
        put :activate, id: collection.id
      end

      it 'should activate the collection' do
        collection.reload.active.must_equal true
      end

      it 'should return a success message' do
        request.flash[:notice].must_equal 'Activated successfully'
      end

      it 'should redirect to admin collections page' do
        assert_redirected_to '/admin/collections'
      end
    end

    context 'invalid collection' do
      before do
        Collection.any_instance.stubs(:update_attribute).returns(false)
        put :activate, id: collection.id
      end

      it 'should not activate the collection' do
        collection.reload.active.must_equal false
      end

      it 'should return a failure message' do
        request.flash[:alert].must_equal 'Activation failed'
      end
    end
  end

  describe '#destroy' do
    before do
      delete :destroy, id: collection.id
    end

    it 'should delete a collection' do
      Collection.count.must_equal 0
    end

    it 'should redirect to admin users page' do
      assert_redirected_to '/admin/collections'
    end
  end

  describe '#edit' do
    it 'should assign a collection' do
      get :edit, id: collection
      assigns(:collection).must_equal collection
    end
  end

  describe '#update' do
    let(:name)        { Faker::App.name }
    let(:description) { Faker::Lorem.word }
    let(:photo)       { create(:photo) }
    let(:cover_photo_data) do
      ActionDispatch::Http::UploadedFile.new(filename: 'image.jpg',
                                             type: 'image/jpeg',
                                             tempfile: File.new(Rails.root + 'test/factories/files/image.jpg'))
    end

    it 'should update collection name' do
      put :update, id: collection.id, collection: { name: name }
      collection.reload.name.must_equal name
    end

    it 'should update collection description' do
      put :update, id: collection.id, collection: { description: description }
      collection.reload.description.must_equal description
    end

    it 'should set cover photo url' do
      put :update, id: collection.id, cover_photo: cover_photo_data
      collection.reload.cover_photo_url.wont_be_nil
    end

    it 'should render edit page' do
      put :update, id: collection.id, collection: { name: nil }
      assert_template :edit
    end

    it 'should update the photo data of collection cover photo' do
      collection.update_attributes(cover_photo_id: photo.id)
      photo.data_filename.must_equal 'everlast.jpg'
      put :update, id: collection.id, cover_photo: cover_photo_data
      photo.reload.data_filename.must_equal 'image.jpg'
    end
  end
end
