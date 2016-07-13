FactoryGirl.define do
  factory Font do
    family_unique_id { SecureRandom.random_number(100_000) }
    family_id        { SecureRandom.random_number(100_000) }
    photo
    user
  end
end
