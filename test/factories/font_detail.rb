FactoryGirl.define do
  factory FontDetail do
    family_id { SecureRandom.random_number(100_000) }
    name      { Faker::Name.name }
    url       { Faker::Internet.url }
    owner     { Faker::Name.name }
  end
end
