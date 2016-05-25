yml = YAML.load(ERB.new(File.read("#{File.dirname(__FILE__)}/../config.yml"), nil, '<>').result(binding))
Object.send(:remove_const, :APP_CONFIG) if defined?(APP_CONFIG)
APP_CONFIG = yml['defaults']
APP_CONFIG.merge!(yml[Rails.env]) unless yml[Rails.env].nil?
