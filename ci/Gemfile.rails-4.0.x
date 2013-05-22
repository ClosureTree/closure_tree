source 'https://rubygems.org'
gemspec :path => '..'

# rspec-rails reverts to 2.3.1 (old and broken) unless you fetch the whole rails enchilada:
gem 'rails', '4.0.0.rc1'
