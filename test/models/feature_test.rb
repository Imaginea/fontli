require 'test_helper'

describe Feature do
  subject { Feature }

  it { must have_fields(:name).of_type(String) }
  it { must have_fields(:active).of_type(Boolean) }

  it { must validate_presence_of(:name) }
  it { must validate_inclusion_of(:name).to_allow(Feature::VALID_FEATURES) }
end
