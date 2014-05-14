source 'https://rubygems.org'
gemspec :path => '..'

# rspec-rails reverts to 2.3.1 (old and broken) unless you fetch the whole rails enchilada:
gem 'rails', '~> 4.1.0'
gem 'foreigner', :git => 'https://github.com/mceachen/foreigner.git'
