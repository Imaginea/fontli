require 'test_helper'

describe Photo do
  let(:user)              { create(:user) }
  let(:photo)             { create(:photo, created_at: Time.now.utc) }
  let(:unpublished_photo) { create(:photo, caption: Photo::DEFAULT_TITLE) }
  let(:sos_requested)     { create(:photo, font_help: true) }
  let(:sos_approved)      { create(:photo, font_help: true, sos_approved: true) }
  let(:photo_data)        { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/everlast.jpg', 'image/jpeg') }

  subject { Photo }

  it { must have_fields(:caption, :data_filename).of_type(String) }
  it { must have_fields(:data_content_type, :data_dimension).of_type(String) }
  it { must have_fields(:data_size).of_type(Integer) }
  it { must have_fields(:latitude, :longitude).of_type(Float) }
  it { must have_fields(:address, :sos_requested_by).of_type(String) }
  it { must have_fields(:sos_approved, :font_help).of_type(Boolean).with_default_value(false) }
  it { must have_fields(:likes_count, :comments_count, :flags_count, :fonts_count).of_type(Integer).with_default_value(0) }
  it { must have_fields(:created_at).of_type(Time) }
  it { must have_fields(:position).of_type(Integer) }
  it { must have_fields(:sos_requested_at, :sos_approved_at).of_type(Time) }
  it { must have_fields(:show_in_homepage, :show_in_header).of_type(Boolean).with_default_value(false) }

  it { must belong_to(:user) }
  it { must belong_to(:workbook) }

  it { must have_index_for(:user_id) }
  it { must have_index_for(:workbook_id) }

  it { must have_many(:fonts) }
  it { must have_many(:likes) }
  it { must have_many(:flags) }
  it { must have_many(:shares) }
  it { must have_many(:comments) }
  it { must have_many(:mentions) }
  it { must have_many(:hash_tags) }
  it { must have_and_belong_to_many(:collections) }

  it { must validate_length_of(:caption).within(2..500) }
  it { must validate_presence_of(:data_filename) }
  it { must validate_inclusion_of(:data_size).to_allow(0..(5.megabytes)).with_message('should be less than 5MB') }
  it { must validate_inclusion_of(:data_content_type).to_allow(Photo::ALLOWED_TYPES).with_message('should be jpg/png') }

  describe 'scope' do
    before do
      photo
      unpublished_photo
      sos_requested
      sos_approved
    end

    it 'should not return unpublished photos' do
      Photo.all.wont_include unpublished_photo
    end

    it 'should return photos' do
      Photo.all.must_include photo
    end

    describe '.recent' do
      it 'should return recently created photos' do
        Photo.recent(10).must_include photo
        Photo.recent(10).must_include sos_requested
        Photo.recent(10).must_include sos_approved
      end
    end

    describe '.unpublished' do
      it 'should return unpublished photos' do
        Photo.unpublished.must_include unpublished_photo
      end

      it 'should not return published photos' do
        Photo.unpublished.wont_include photo
      end
    end

    describe '.sos_requested' do
      it 'should return requested sos' do
        Photo.sos_requested.must_include sos_requested
      end

      it 'should not return approved sos' do
        Photo.sos_requested.wont_include sos_approved
      end
    end

    describe '.non_sos_requested' do
      it 'should return approved sos' do
        Photo.non_sos_requested.must_include sos_approved
      end

      it 'should not return requested sos' do
        Photo.non_sos_requested.wont_include sos_requested
      end
    end

    describe '.geo_tagged' do
      let(:photo1) { create(:photo, latitude: Faker::Address.latitude, longitude: Faker::Address.longitude) }
      let(:photo2) { create(:photo, latitude: 0, longitude: 0) }

      before do
        photo1
        photo2
      end

      it 'should return geo_tagged photo' do
        Photo.geo_tagged.must_include photo1
      end

      it 'should not return non-geo_tagged photo' do
        Photo.geo_tagged.wont_include photo2
      end
    end

    describe '.all_popular' do
      before do
        create_list(:like, 2, photo: photo)
        photo.reload
      end

      it 'should return photos having likes_count greater than 1' do
        Photo.all_popular.must_include photo
      end

      it 'should not return photos without any likes' do
        Photo.all_popular.wont_include unpublished_photo
      end
    end

    describe '.for_homepage' do
      let(:photo1) { create(:photo, show_in_homepage: true) }

      it 'should return photos for homepage' do
        Photo.for_homepage.must_include photo1
      end

      it 'should not return photos not for homepage' do
        Photo.for_homepage.wont_include photo
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save' do
      it 'should set sos_approved_at if sos_approved is set' do
        new_photo = build(:photo, sos_approved: true)
        new_photo.sos_approved_at.must_be_nil
        new_photo.save
        new_photo.sos_approved_at.wont_be_nil
      end

      it 'should not set_approved_at if sos_approved is not set' do
        new_photo = build(:photo)
        new_photo.save
        new_photo.sos_approved_at.must_be_nil
      end
    end

    describe 'after_create' do
      it 'should populate mentions if its caption contain username' do
        photo = create(:photo, caption: "mention @#{user.username}")
        photo.mentions.wont_be_empty
      end
    end

    describe 'after_save' do
      let(:new_photo) { build(:photo, data: photo_data) }

      it 'should save data to a file' do
        File.directory?(Photo::FOTO_DIR + "/#{new_photo.id}").must_equal false
        new_photo.save
        File.directory?(Photo::FOTO_DIR + "/#{new_photo.id}").must_equal true
      end
    end

    describe 'after_destroy' do
      before do
        photo
      end

      it 'should delete the directory of photo data' do
        File.directory?(Photo::FOTO_DIR + "/#{photo.id}").must_equal true

        photo.destroy
        File.directory?(Photo::FOTO_DIR + "/#{photo.id}").must_equal false
      end
    end
  end

  describe '.[]' do
    it 'should return a photo having the provided id' do
      Photo[photo.id].must_equal photo
    end

    it 'should not return a photo not having the provided id' do
      Photo[photo.id].wont_equal unpublished_photo
    end
  end

  describe '.in_batches' do
    before do
      unpublished_photo
    end

    it 'should process the photos in batches' do
      Photo.unpublished.count.must_equal 1

      Photo.in_batches(10, caption: Photo::DEFAULT_TITLE) do |photos|
        photos.each do |photo|
          photo.update_attribute(:caption, Faker::Lorem.word)
        end
      end
      Photo.unpublished.count.must_equal 0
    end
  end

  describe '.human_attribute_name' do
    it 'should transform attributes key name in humane format' do
      Photo.human_attribute_name('data_filename').must_equal 'Filename'
      Photo.human_attribute_name('data_size').must_equal 'File size'
      Photo.human_attribute_name('data_content_type').must_equal 'File type'
    end
  end

  describe '.save_data' do
    it 'should create a new photo' do
      Photo.unpublished.count.must_equal 0
      Photo.save_data(data: photo_data)
      Photo.unpublished.count.must_equal 1
    end

    it 'should updata a photo' do
      options = { data: Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/image.jpg', 'image/jpeg'), user_id: unpublished_photo.user_id }
      Photo.save_data(options)
      unpublished_photo.reload.data_filename.must_equal 'image.jpg'
    end
  end

  describe '.publish' do
    it 'should publish a unpublished photo' do
      opts = { photo_id: unpublished_photo.id, caption: Faker::Lorem.word }
      Photo.publish(opts)
      unpublished_photo.reload.caption.must_equal opts[:caption]
    end

    it 'should set it as sos' do
      opts = { photo_id: unpublished_photo.id,
               caption: Faker::Lorem.word,
               font_help: true }
      Photo.publish(opts)
      unpublished_photo.reload.font_help.must_equal true
    end
  end

  describe '.add_like_for' do
    it 'should return photo not found' do
      Photo.add_like_for(SecureRandom.hex(3), user.id).must_equal [nil, :photo_not_found]
    end

    it 'should add a like for a photo' do
      photo.likes.count.must_equal 0
      Photo.add_like_for(photo.id, user.id)
      photo.reload.likes.count.must_equal 1
    end
  end

  describe '.unlike_for' do
    let(:like) { create(:like, photo: photo) }

    before do
      like
    end

    it 'should return record not found' do
      Photo.unlike_for(SecureRandom.hex(3), user.id).must_equal [nil, :record_not_found]
    end

    it 'should remove a like' do
      Photo.unlike_for(photo.id, like.user_id)
      photo.reload.likes_count.must_equal 0
    end
  end

  describe '.add_flag_for' do
    it 'should return photo not found' do
      Photo.add_flag_for(SecureRandom.hex(3), user.id).must_equal [nil, :photo_not_found]
    end

    it 'should add a flag for a photo' do
      photo.flags.count.must_equal 0
      Photo.add_flag_for(photo.id, user.id)
      photo.reload.flags.count.must_equal 1
    end
  end

  describe '.add_share_for' do
    it 'should return photo not found' do
      Photo.add_flag_for(SecureRandom.hex(3), user.id).must_equal [nil, :photo_not_found]
    end

    it 'should add a share for a photo' do
      photo.shares.count.must_equal 0
      Photo.add_share_for(photo.id, user.id)
      photo.reload.shares.count.must_equal 1
    end
  end

  describe '.add_comment_for' do
    it 'should return photo not found' do
      Photo.add_comment_for(photo_id: SecureRandom.hex(3)).must_equal [nil, :photo_not_found]
    end

    it 'should add a comment for a photo' do
      photo.comments.count.must_equal 0
      opts = { photo_id: photo.id, body: Faker::Lorem.word, user_id: user.id }
      Photo.add_comment_for(opts)
      photo.reload.comments.count.must_equal 1
    end

    it 'should add a font_tag' do
      opts = { photo_id: photo.id,
               body: Faker::Lorem.word,
               user_id: user.id,
               font_tags: [{ family_unique_id: SecureRandom.hex(4),
                             family_id: SecureRandom.hex(4),
                             subfont_id: SecureRandom.hex(4),
                             coords: "#{Faker::Number.decimal(2)}, #{Faker::Number.decimal(2)}" }.with_indifferent_access] }
      Photo.add_comment_for(opts)
      photo.reload.fonts.count.must_equal 1
      FontTag.count.must_equal 1
    end

    it 'should add a hash tag' do
      opts = { photo_id: photo.id,
               body: Faker::Lorem.word,
               user_id: user.id,
               hashes: [{ name: Faker::Lorem.word }] }
      Photo.add_comment_for(opts)
      photo.reload.hash_tags.count.must_equal 1
    end
  end

  describe '.feeds_for' do
    it 'should return feeds for a user' do
      Photo.feeds_for(photo.user).must_include photo
    end
  end

  describe '.cached_popular' do
    before do
      create_list(:like, 2, photo: photo)
      photo.reload
    end

    it 'should caches and return popular photo' do
      Photo.cached_popular.must_include photo
    end
  end

  describe '.popular' do
    before do
      create_list(:like, 2, photo: photo)
      photo.reload
    end

    it 'should return cached photo' do
      Photo.popular.must_include photo
    end
  end

  describe 'random_popular' do
    let(:popular_photo) { create(:photo, show_in_header: true) }
    before do
      create_list(:like, 2, photo: photo)
      create_list(:like, 2, photo: popular_photo)
      photo.reload
      popular_photo.reload
    end

    it 'should return popular photo with show_in_header set as true' do
      Photo.random_popular.must_include popular_photo
    end

    it 'should not return popular photo with show_in_header set as false' do
      Photo.random_popular.wont_include photo
    end
  end

  describe '.all_by_hash_tag' do
    let(:hash_tag) { create(:hash_tag) }

    it 'should return blank' do
      Photo.all_by_hash_tag([]).must_be_empty
    end

    it 'should return the photos having hash_tags with the provided tag_name' do
      Photo.all_by_hash_tag(hash_tag.name).must_include hash_tag.photo
    end
  end

  describe '.sos' do
    before do
      sos_approved
    end

    it 'should return sos' do
      Photo.sos.must_include sos_approved
    end
  end

  describe '.flagged_ids' do
    before do
      create_list(:flag, 6, photo: photo)
    end

    it 'should return ids of photos with flags count greater than 5' do
      Photo.flagged_ids.must_include photo.id
    end
  end

  describe '.search' do
    let(:other_photo) { create(:photo, caption: Faker::Lorem.word) }

    it 'should return blank' do
      Photo.search([]).must_be_empty
    end

    it 'should return photos having the provided caption' do
      Photo.search(other_photo.caption).must_include other_photo
    end
  end

  describe '.search_autocomplete' do
    let(:other_photo) { create(:photo, caption: Faker::Lorem.word) }

    it 'should return empty array if photos are not found whose caption is same as the provided caption' do
      Photo.search_autocomplete(Faker::Lorem.word).must_be_empty
    end

    it 'should return array of caption of photos having the provided caption' do
      Photo.search_autocomplete(other_photo.caption).must_include other_photo.caption
    end
  end

  describe '#data=' do
    let(:data) { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/image.jpg', 'image/jpeg') }

    it 'should set user data attributes' do
      photo.data = data
      photo.data_filename.must_equal 'image.jpg'
      photo.data_content_type.must_equal 'image/jpeg'
    end
  end

  describe '#path' do
    it 'should return avatar path' do
      photo.path.must_equal "#{Photo::FOTO_DIR}/#{photo.id}/original.#{photo.send(:extension)}"
    end
  end

  describe '#url' do
    it 'should return data url' do
      photo.url.must_equal "#{request_domain}/test_photos/#{photo.id}/original.#{photo.send(:extension)}"
    end
  end

  describe '#aws_url' do
    it 'should return data aws url' do
      photo.aws_url('original').must_equal "#{Photo::AWS_SERVER_PATH}#{photo.id}_original.#{photo.send(:extension)}"
    end
  end

  describe '#aws_path' do
    it 'should return data aws url' do
      photo.aws_path('original').must_equal "#{photo.id}_original.#{photo.send(:extension)}"
    end
  end

  describe '#url_thumb' do
    it 'should return data url thumb' do
      photo.url_thumb.must_equal "#{request_domain}/test_photos/#{photo.id}/thumb.#{photo.send(:extension)}"
    end
  end

  describe '#url_large' do
    it 'should return data url thumb' do
      photo.url_large.must_equal "#{request_domain}/test_photos/#{photo.id}/large.#{photo.send(:extension)}"
    end
  end

  describe '#url_medium' do
    it 'should return data url thumb' do
      photo.url_medium.must_equal "#{request_domain}/test_photos/#{photo.id}/medium.#{photo.send(:extension)}"
    end
  end

  describe '#crop?' do
    it 'should return false' do
      photo.crop?.must_equal false
    end

    it 'should return true' do
      photo.crop_x = photo.crop_y = photo.crop_w = photo.crop_h = 1
      photo.crop?.must_equal true
    end
  end

  describe '#crop=' do
    it 'should set crop properties' do
      photo.crop = { crop_x: '1', crop_y: '2', crop_w: '3', crop_h: '4' }
      photo.crop_x.must_equal '1'
      photo.crop_y.must_equal '2'
      photo.crop_w.must_equal '3'
      photo.crop_h.must_equal '4'
    end
  end

  describe '#font_tags=' do
    it 'should build font_tags and comments' do
      photo.font_tags = [{ family_unique_id: SecureRandom.hex(4),
                           family_id: SecureRandom.hex(4),
                           subfont_id: SecureRandom.hex(4),
                           coords: "#{Faker::Number.decimal(2)}, #{Faker::Number.decimal(2)}" }.with_indifferent_access]
      photo.save
      photo.fonts.count.must_equal 1
      FontTag.count.must_equal 1
      photo.comments.count.must_equal 1
    end
  end

  describe '#hashes' do
    it 'should build hash tags' do
      photo.hashes = [{ name: Faker::Lorem.word }]
      photo.save
      photo.hash_tags.count.must_equal 1
    end
  end

  describe '#collection_names=' do
    it 'should create a new collection' do
      photo.collection_names = [Faker::Lorem.word]
      photo.collections.count.must_equal 1
    end

    it 'should not create collection' do
      photo.collection_names = []
      photo.collections.count.must_equal 0
    end
  end

  describe '#collection_names' do
    let(:collection)  { create(:collection, active: true) }
    let(:collection1) { create(:collection, active: true) }

    before do
      collection.photos << photo
      collection1.photos << photo
    end

    it 'should return action collection names' do
      photo.collection_names.must_equal "#{collection.name}||#{collection1.name}"
    end
  end

  describe '#add_to_collections' do
    let(:collection) { create(:collection) }

    it 'should add the collection to the collection list' do
      photo.add_to_collections([collection.name])
      photo.reload.collections.must_include collection
    end
  end

  describe '#aspect_fit' do
    let(:image_data) { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/image.jpg', 'image/jpeg') }
    let(:other_photo) { create(:photo, data: image_data) }

    it 'should return image height and width' do
      other_photo.aspect_fit(75, 75).must_equal [75, 30]
    end
  end

  describe '#username' do
    it 'should return username of its user' do
      photo.username.must_equal photo.user.username
    end
  end

  describe '#user_url_thumb' do
    it 'should return its user url_thum' do
      photo.user_url_thumb.must_equal photo.user.url_thumb
    end
  end

  describe '#top_fonts' do
    let(:font)  { create(:font, photo: sos_approved, pick_status: 2) }
    let(:font1) { create(:font, photo: sos_approved) }

    before do
      font
      create_list(:agree, 11, font: font1)
      sos_approved.reload
    end

    it 'should return its fonts with pick_status greater than zero' do
      sos_approved.top_fonts.must_include font
    end

    it 'should return its fonts with agrees_count greater than 10' do
      sos_approved.top_fonts.must_include font1
    end

    it 'should be empty if no fonts found' do
      photo.top_fonts.must_be_empty
    end
  end

  describe '#most_agreed_font' do
    let(:font)  { create(:font, photo: sos_approved) }
    let(:font1) { create(:font, photo: sos_approved) }

    before do
      create_list(:agree, 11, font: font)
      create_list(:agree, 1, font: font1)
    end

    it 'should return fonts with most agrees count' do
      sos_approved.most_agreed_font.must_equal font
    end
  end

  describe '#font_ord' do
    let(:font)  { create(:font, photo: sos_approved, pick_status: 3) }
    let(:font1) { create(:font, photo: sos_approved) }
    let(:font2) { create(:font, photo: sos_approved) }

    before do
      font
      create_list(:agree, 3, font: font1)
      create_list(:font_tag, 3, font: font2)
    end

    it 'should order fonts by pick_status, agrees_count and tags_count' do
      sos_approved.fonts_ord.must_equal [font, font1, font2]
    end
  end

  describe '#liked?' do
    it 'should return false' do
      photo.liked?.must_equal false
    end
  end

  describe '#commented?' do
    it 'should return false' do
      photo.commented?.must_equal false
    end
  end

  describe '#populate_liked_commented_users' do
    let(:like)    { create(:like, photo: photo) }
    let(:comment) { create(:comment, photo: photo) }

    before do
      like
      comment
    end

    it 'should populate only liked_user' do
      photo.populate_liked_commented_users(only_likes: true)
      photo.liked_user.must_equal like.user.username
      photo.commented_user.must_equal ''
    end

    it 'should populate only commented_user' do
      photo.populate_liked_commented_users(only_comments: true)
      photo.commented_user.must_equal comment.user.username
      photo.liked_user.must_equal ''
    end

    it 'should populate both liked_user and commented_user' do
      photo.populate_liked_commented_users
      photo.liked_user.must_equal like.user.username
      photo.commented_user.must_equal comment.user.username
    end

    it 'should not populate both liked_user and commented_user' do
      unpublished_photo.populate_liked_commented_users
      unpublished_photo.liked_user.must_be_nil
      unpublished_photo.commented_user.must_be_nil
    end
  end

  describe '#crop_file' do
    it 'should return true' do
      photo.send(:crop_file).must_equal true
    end

    it 'should set its data_dimenstion' do
      photo.crop_x = photo.crop_y = photo.crop_w = photo.crop_h = 1
      photo.send(:crop_file)
      photo.data_dimension.must_equal '1x1'
    end
  end

  describe '#photos_count' do
    it 'should return 1' do
      photo.send(:photos_count).must_equal 1
    end
  end
end
