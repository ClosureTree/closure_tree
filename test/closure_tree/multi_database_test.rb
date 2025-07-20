# frozen_string_literal: true

require 'test_helper'

class MultiDatabaseTest < ActiveSupport::TestCase
  def setup
    super
    # Create memory tables - always recreate for clean state
    SqliteRecord.connection.create_table :memory_tags, force: true do |t|
      t.string :name
      t.integer :parent_id
      t.timestamps
    end

    SqliteRecord.connection.create_table :memory_tag_hierarchies, id: false, force: true do |t|
      t.integer :ancestor_id, null: false
      t.integer :descendant_id, null: false
      t.integer :generations, null: false
    end

    SqliteRecord.connection.add_index :memory_tag_hierarchies, %i[ancestor_id descendant_id generations],
                                      unique: true, name: 'memory_tag_anc_desc_idx'
    SqliteRecord.connection.add_index :memory_tag_hierarchies, [:descendant_id], name: 'memory_tag_desc_idx'
  end

  def teardown
    # Clean up SQLite tables after each test
    SqliteRecord.connection.drop_table :memory_tag_hierarchies, if_exists: true
    SqliteRecord.connection.drop_table :memory_tags, if_exists: true
    super
  end

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
    skip 'MySQL not configured' unless mysql?(MysqlRecord.connection)

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
    tag = MemoryTag.create!(name: 'SQLite Root')

    # Advisory locks should be disabled for SQLite but operations should still work
    # Closure tree internally handles the lack of advisory locks
    child = tag.children.create!(name: 'SQLite Child')

    assert_equal tag, child.parent
    assert tag.descendants.include?(child)
  end

  def test_concurrent_operations_different_databases
    # Create roots in different databases
    pg_tag = nil
    if postgresql?(ApplicationRecord.connection)
      pg_tag = Tag.create!(name: 'PG Root')
      # Create child directly, not in a thread, to avoid database cleaner issues
      pg_tag.children.create!(name: 'PG Child 1')
    end

    mysql_tag = MysqlTag.create!(name: 'MySQL Root')
    sqlite_tag = MemoryTag.create!(name: 'SQLite Root')

    # Test concurrent operations only for MySQL and SQLite
    threads = []

    threads << Thread.new do
      MysqlRecord.connection_pool.with_connection do
        tag = MysqlTag.find(mysql_tag.id)
        tag.children.create!(name: 'MySQL Child 1')
      end
    end

    threads << Thread.new do
      SqliteRecord.connection_pool.with_connection do
        tag = MemoryTag.find(sqlite_tag.id)
        tag.children.create!(name: 'SQLite Child 1')
      end
    end

    threads.each(&:join)

    # Verify all children were created
    assert_equal 1, pg_tag.reload.children.count if pg_tag
    assert_equal 1, mysql_tag.reload.children.count
    assert_equal 1, sqlite_tag.reload.children.count
  end
end
