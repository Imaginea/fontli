ENV['RAILS_ENV'] ||= 'test'
require 'simplecov'
SimpleCov.start 'rails'

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'minitest/autorun'
require 'mongoid'
require 'mongoid-minitest'
require 'action_controller/test_case'
require 'active_support/testing/assertions'
require 'mocha/mini_test'

Dir[Rails.root.join('test/support/**/*.rb')].each { |f| require f }
DatabaseCleaner[:mongoid].strategy = :truncation

class MiniTest::Spec
  include Mongoid::Matchers
  include FactoryGirl::Syntax::Methods
  include MongoExtensions
  include ActiveSupport::Testing::SetupAndTeardown

  # Allow context to be used like describe
  class << self
    alias context describe
  end

  before :each do
    DatabaseCleaner.start
  end

  after :each do
    DatabaseCleaner.clean
    FileUtils.rm_rf(File.join(Rails.root, 'public', 'test_avatars'))
    FileUtils.rm_rf(File.join(Rails.root, 'public', 'test_photos'))
    Thread.current[:current_controller] = nil
  end
end

class ControllerSpec < MiniTest::Spec
  include Rails.application.routes.url_helpers
  include ActionController::TestCase::Behavior
  include Test::Unit::Assertions
  include ActiveSupport::Testing::Assertions

  before do
    @routes = Rails.application.routes
  end

  def self.determine_default_controller_class(name)
    # Override this method to support nested describe
    # Original implementation:
    # name.sub(/Test$/, '').safe_constantize
    name.split('::').reverse.map do |n|
      n.sub(/Test$/, '').safe_constantize
    end.compact.first
  end
end

# Test subjects ending with 'Controller' are treated as functional tests
#   e.g. describe TestController do ...
MiniTest::Spec.register_spec_type(/Controller$/, ControllerSpec)
