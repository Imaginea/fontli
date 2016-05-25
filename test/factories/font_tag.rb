FactoryGirl.define do
  factory FontTag do
    coords_x { Faker::Number.decimal(2) }
    coords_y { Faker::Number.decimal(2) }
    font
    user
  end
end
