FactoryGirl.define do
  factory StorifyStory do
    text   Faker::Lorem.sentence
    name   Faker::Name.name
    avatar Faker::Avatar.image
  end
end
