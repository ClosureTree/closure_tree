
appraise 'activerecord-4.2' do
  gem 'activerecord', '~> 4.2.0'
  platforms :ruby do
    gem 'mysql2', "< 0.5"
    gem 'pg', "~> 0.21"
    gem 'sqlite3', '~> 1.3.13'
  end

  platforms :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end

appraise 'activerecord-5.0' do
  gem 'activerecord', '~> 5.0.0'
  platforms :ruby do
    gem 'mysql2'
    gem 'pg'
    gem 'sqlite3', '~> 1.3.13'
  end

  platforms :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end

appraise 'activerecord-5.1' do
  gem 'activerecord', '~> 5.1.0'
  platforms :ruby do
    gem 'mysql2'
    gem 'pg'
    gem 'sqlite3', '~> 1.3.13'
  end

  platforms :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  end
end

appraise 'activerecord-5.2' do
  gem 'activerecord', '~> 5.2.0'
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
