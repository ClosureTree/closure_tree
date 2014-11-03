source 'https://rubygems.org'
gem 'foreigner', :git => 'https://github.com/matthuhiggins/foreigner.git'

platforms :ruby, :rbx do
  gem 'mysql2'
  gem 'pg'
  gem 'sqlite3'
end

platforms :jruby do
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'activerecord-jdbcsqlite3-adapter'
end

gemspec
