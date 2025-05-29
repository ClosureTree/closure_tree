# frozen_string_literal: true

namespace :db do
  namespace :test do
    desc 'Load schema for all databases'
    task prepare: :environment do
      # Load schema for primary database
      ActiveRecord::Base.establish_connection(:primary)
      ActiveRecord::Schema.define(version: 1) do
        create_table 'tags', force: true do |t|
          t.string 'name'
        end

        create_table 'tag_audits', id: false, force: true do |t|
          t.string 'tag_name'
        end

        create_table 'labels', id: false, force: true do |t|
          t.string 'name'
        end
      end

      # Load schema for secondary database
      ActiveRecord::Base.establish_connection(:secondary)
      ActiveRecord::Schema.define(version: 1) do
        create_table 'mysql_tags', force: true do |t|
          t.string 'name'
        end

        create_table 'mysql_tag_audits', id: false, force: true do |t|
          t.string 'tag_name'
        end

        create_table 'mysql_labels', id: false, force: true do |t|
          t.string 'name'
        end
      end
    end
  end
end
