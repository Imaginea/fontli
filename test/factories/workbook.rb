FactoryGirl.define do
  factory Workbook do
    user
    title Faker::Name.name
    description Faker::Lorem.sentence
  end
end
