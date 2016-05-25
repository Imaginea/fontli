require 'test_helper'

describe UserFlag do
  subject { UserFlag }

  it { must belong_to(:user) }
  it { must belong_to(:from_user) }

  it { must have_index_for(:user_id) }
  it { must have_index_for(:from_user_id) }

  it { must validate_uniqueness_of(:from_user_id).scoped_to(:user_id).with_message('has already flagged!') }
end
