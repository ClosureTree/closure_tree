source 'https://rubygems.org'
gemspec :path => '..'

gem 'activerecord', '~> 3.0.0'
gem 'mysql2', '< 0.3.0' # See https://github.com/brianmario/mysql2/issues/155
gem 'strong_parameters'
