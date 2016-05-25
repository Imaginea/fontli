require 'test_helper'

describe Flag do
  subject { Flag }

  it { must belong_to(:user) }
  it { must belong_to(:photo) }

  it { must have_index_for(:user_id) }
  it { must have_index_for(:photo_id) }

  it { must validate_uniqueness_of(:user_id).scoped_to(:photo_id).with_message('has already flagged!') }
end
