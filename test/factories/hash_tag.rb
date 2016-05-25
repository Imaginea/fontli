FactoryGirl.define do
  factory HashTag do
    name { Faker::Name.name }
    association :hashable, factory: :photo
  end
end
