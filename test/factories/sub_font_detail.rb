FactoryGirl.define do
  factory SubFontDetail do
    style_id SecureRandom.random_number(1_000_000)
    name     Faker::Name.name
    url      Faker::Internet.url
    font_detail { FactoryGirl.build(:font_detail) }
  end
end
