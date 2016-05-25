FactoryGirl.define do
  factory Suggestion do
    user
    text Faker::Lorem.sentence
  end
end
