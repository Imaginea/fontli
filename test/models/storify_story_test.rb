require 'test_helper'

describe StorifyStory do
  let(:storify_story) { create(:storify_story) }

  subject { StorifyStory }

  it { must have_field(:link, :text, :name, :avatar).of_type(String) }

  it { must validate_presence_of(:text) }
  it { must validate_presence_of(:name) }
  it { must validate_presence_of(:avatar) }

  describe '.random_story' do
    before do
      storify_story
    end

    it 'should return a story if exists' do
      StorifyStory.random_story.wont_be_nil
    end
  end
end
