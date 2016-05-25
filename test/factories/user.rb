FactoryGirl.define do
  factory User do
    username { Faker::Name.name[0..14].gsub!(/\W/, '') }
    email    { Faker::Internet.email }
    password 'fontli111'

    trait :with_platform do
      platform  %w(twitter facebook).sample
      extuid    { SecureRandom.hex(6) }
    end

    trait :admin do
      admin true
    end

    trait :expert do
      expert true
    end

    trait :with_fullname do
      full_name { Faker::Name.name }
    end

    trait :with_avatar do
      avatar Rack::Test::UploadedFile.new(Rails.root + 'test/factories/files/everlast.jpg', 'image/jpeg')
    end
  end
end
