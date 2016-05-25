FactoryGirl.define do
  factory Photo do
    data { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/everlast.jpg', 'image/jpeg') }
    user
  end
end
