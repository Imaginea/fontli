FactoryGirl.define do
  factory Mention do
    username Faker::Name.name
    association :mentionable, factory: :photo
    user
  end
end
