require 'test_helper'

describe Suggestion do
  let(:suggestion)          { create(:suggestion) }
  let(:notified_suggestion) { create(:suggestion, notified: true, sugg_type: 'found a bug') }

  subject { Suggestion }

  it { must have_fields(:text, :sugg_type, :platform, :os_version, :app_version).of_type(String) }
  it { must have_fields(:notified).of_type(Boolean).with_default_value(false) }

  it { must belong_to(:user) }

  it { must have_index_for(:user_id) }

  it { must validate_presence_of(:user_id) }
  it { must validate_presence_of(:text) }
  it { must validate_length_of(:text).with_maximum(500) }

  describe '.unnotified' do
    before do
      suggestion
      notified_suggestion
    end

    it 'should not return notified suggestion' do
      Suggestion.unnotified.wont_include notified_suggestion
    end

    it 'should return unnotified suggestion' do
      Suggestion.unnotified.must_include suggestion
    end
  end

  describe '#mail_to' do
    it 'should return support email if its related to bug' do
      notified_suggestion.mail_to.must_equal 'support@fontli.com'
    end

    it 'should return info email incase its not a bug' do
      suggestion.mail_to.must_equal 'info@fontli.com'
    end
  end
end
