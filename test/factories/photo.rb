FactoryGirl.define do
  factory Photo do
    data { Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/everlast.jpg', 'image/jpeg') }
    user

    trait :with_caption do
      caption { Faker::Lorem.characters(5) }
    end
  end
end
