# frozen_string_literal: true

require 'test_helper'

class MultiDatabaseTest < ActiveSupport::TestCase
  def test_postgresql_with_advisory_lock
    skip 'PostgreSQL not configured' unless postgresql?(ApplicationRecord.connection)

    tag = Tag.create!(name: 'PostgreSQL Root')
    child = nil

    # Advisory locks should work on PostgreSQL
    Tag.with_advisory_lock('test_lock') do
      child = tag.children.create!(name: 'PostgreSQL Child')
    end

    assert_equal tag, child.parent
    assert tag.descendants.include?(child)
  end

  def test_mysql_with_advisory_lock
    skip 'MySQL not configured' unless defined?(MysqlRecord) && mysql?(MysqlRecord.connection)

    tag = MysqlTag.create!(name: 'MySQL Root')
    child = nil

    # Advisory locks should work on MySQL
    MysqlTag.with_advisory_lock('test_lock') do
      child = tag.children.create!(name: 'MySQL Child')
    end

    assert_equal tag, child.parent
    assert tag.descendants.include?(child)
  end

  def test_sqlite_without_advisory_lock
    skip 'SQLite not configured' unless defined?(SqliteRecord)

    tag = SqliteTag.create!(name: 'SQLite Root')
    child = nil

    # Advisory locks should be disabled for SQLite but operations should still work
    SqliteTag.with_advisory_lock('test_lock') do
      child = tag.children.create!(name: 'SQLite Child')
    end

    assert_equal tag, child.parent
    assert tag.descendants.include?(child)
  end

  def test_concurrent_operations_different_databases
    skip 'Multi-database not configured' unless defined?(MysqlRecord) && defined?(SqliteRecord)

    # Create roots in different databases
    pg_tag = Tag.create!(name: 'PG Root') if postgresql?(ApplicationRecord.connection)
    mysql_tag = MysqlTag.create!(name: 'MySQL Root')
    sqlite_tag = SqliteTag.create!(name: 'SQLite Root')

    # Operations should work independently
    threads = []

    if pg_tag
      threads << Thread.new do
        pg_tag.children.create!(name: 'PG Child 1') if pg_tag
      end
    end

    threads << Thread.new do
      mysql_tag.children.create!(name: 'MySQL Child 1')
    end

    threads << Thread.new do
      sqlite_tag.children.create!(name: 'SQLite Child 1')
    end

    threads.each(&:join)

    # Verify all children were created
    assert_equal 1, pg_tag.reload.children.count if pg_tag
    assert_equal 1, mysql_tag.reload.children.count
    assert_equal 1, sqlite_tag.reload.children.count
  end
end
