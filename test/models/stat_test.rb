require 'test_helper'

describe Stat do
  let(:stat) { create(:stat) }

  subject { Stat }

  it { must have_fields(:name).of_type(String).with_default_value(Stat::CURRENT_STAT_NAME) }
  it { must have_fields(:app_version).of_type(String) }
  it { must have_fields(:photo_verify_thumbs_ran_at, :photo_fixup_thumbs_ran_at, :font_details_cached_at, :font_fixup_missing_ran_at, :myfonts_api_access_start).of_type(Time) }
  it { must have_fields(:photo_likes_count_checked_at).of_type(Time).with_default_value('2014-12-24 00:00:00 IST') }
  it { must have_fields(:myfonts_api_access_count).of_type(Integer) }

  describe '.current' do
    it 'should create a current stat' do
      Stat.count.must_equal 0
      Stat.current.wont_be_nil
    end

    it 'should return existing current stat' do
      stat
      Stat.current.must_equal stat
    end
  end

  describe '.expire_popular_cache!' do
    it 'should clear all the cache' do
      Stat.expire_popular_cache!.must_equal false
    end
  end

  describe '#misc_attrs' do
    it 'should return other than known attributes' do
      stat.misc_attrs.wont_be_nil
    end
  end

  describe '#increment_myfonts_api_access_count!' do
    it 'should set the myfonts_api_access_start attribute' do
      stat.myfonts_api_access_start.must_be_nil
      stat.increment_myfonts_api_access_count!
      stat.myfonts_api_access_start.wont_be_nil
      stat.myfonts_api_access_count.must_equal 1
    end

    it 'should update myfonts_api_access_start to current time' do
      time = Time.now.utc - 2.hour
      stat = create(:stat, myfonts_api_access_start: time)
      stat.increment_myfonts_api_access_count!
      stat.myfonts_api_access_start.wont_equal time
      stat.myfonts_api_access_count.must_equal 0
    end
  end

  describe '#can_access_myfonts?' do
    it 'should return true' do
      stat.can_access_myfonts?.must_equal true
    end

    it 'should return false' do
      stat = create(:stat, myfonts_api_access_count: 500)
      stat.can_access_myfonts?.must_equal false
    end
  end
end
