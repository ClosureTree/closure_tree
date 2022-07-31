# frozen_string_literal: true

appraise 'activerecord-6.0' do
  gem 'activerecord', '~> 6.0.0'
  platforms :ruby do
    gem 'mysql2'
    gem 'pg'
    gem 'sqlite3'
  end

  platforms :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end

appraise 'activerecord-6.1' do
  gem 'activerecord', '~> 6.1.0'
  platforms :ruby do
    gem 'mysql2'
    gem 'pg'
    gem 'sqlite3'
  end

  platforms :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end

appraise 'activerecord-7.0' do
  gem 'activerecord', '~> 7.0.0'
  platforms :ruby do
    gem 'mysql2'
    gem 'pg'
    gem 'sqlite3'
  end

  platforms :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end

appraise 'activerecord-edge' do
  gem 'activerecord', github: 'rails/rails'
  platforms :ruby do
    gem 'mysql2'
    gem 'pg'
    gem 'sqlite3'
  end

  platforms :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end
