Closure Tree
============

Closure Tree is a mostly-API-compatible replacement for the
acts_as_tree and awesome_nested_set gems, but with much better
mutation performance thanks to the Closure Tree storage algorithm.

See [Bill Karwin](http://karwin.blogspot.com/)'s excellent 
[Models for hierarchical data presentation](http://www.slideshare.net/billkarwin/models-for-hierarchical-data)
for a description of different tree storage algorithms.

## Setup

Note that closure-tree is being developed for Rails 3.0 and 3.1 (currently in beta).

1. Add this to your Gemfile:

        gem 'closure-tree'

2. Run

        bundle install

3. Add a database migration to store the hierarchy for your model. By
convention the table name will be the model's table name, followed by
"_hierarchy":

        class CreateTagHierarchy < ActiveRecord::Migration
          def self.up
            create_table :tag_hierarchy do |t|
              t.integer  :ancestor_id, :null => false   # ID of the parent/grandparent/great-grandparent/... tag
              t.integer  :descendant_id, :null => false # ID of the target tag
              t.integer  :generations, :null => false   # Number of generations between the ancestor and the descendant. Parent/child = 1, for example.
            end

            # For "all progeny of..." selects:
            add_index :tag_hierarchy, [:ancestor_id, :descendant_id], :unique => true

            # For "all ancestors of..." selects
            add_index :tag_hierarchy, [:descendant_id]
          end

          def self.down
            drop_table :tag_hierarchy
          end
        end
