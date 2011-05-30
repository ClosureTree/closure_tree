# Closure Tree

Closure Tree is a mostly-API-compatible replacement for the
acts_as_tree and awesome_nested_set gems, but with much better
mutation performance thanks to the Closure Tree storage algorithm.

See [Bill Karwin](http://karwin.blogspot.com/)'s excellent
[Models for hierarchical data presentation](http://www.slideshare.net/billkarwin/models-for-hierarchical-data)
for a description of different tree storage algorithms.

## Setup

Note that closure_tree is being developed for Rails 3.1.0.rc1

1.  Add this to your Gemfile: ```gem 'closure_tree'```

2.  Run ```bundle install```

3.  Add ```acts_as_tree``` to your hierarchical model(s).

4.  Add a migration to add a ```parent_id``` column to the model you want to act_as_tree.

    Note that if the column is null, the tag will be considered a root node.

      ```ruby
      class AddParentIdToTag < ActiveRecord::Migration
        def change
          add_column :tag, :parent_id, :integer
        end
      end
      ```

5.  Add a database migration to store the hierarchy for your model. By
    convention the table name will be the model's table name, followed by
    "_hierarchy". Note that by calling ```acts_as_tree```, a "virtual model" (in this case, ```TagsHierarchy```) will be added automatically, so you don't need to create it.

        ```ruby
        class CreateTagHierarchy < ActiveRecord::Migration
        def change
          create_table :tags_hierarchy, :id => false do |t|
            t.integer  :ancestor_id, :null => false   # ID of the parent/grandparent/great-grandparent/... tag
            t.integer  :descendant_id, :null => false # ID of the target tag
            t.integer  :generations, :null => false   # Number of generations between the ancestor and the descendant. Parent/child = 1, for example.
          end

          # For "all progeny of..." selects:
          add_index :tags_hierarchy, [:ancestor_id, :descendant_id], :unique => true

          # For "all ancestors of..." selects
          add_index :tags_hierarchy, [:descendant_id]
        end
      end
      ```

6.  Run ```rake db:migrate```

7.  If you're migrating away from another system where your model already has a
    ```parent_id``` column, run ```Tag.rebuild!``` and the
    ..._hierarchy table will be truncated and rebuilt.

    If you're starting from scratch you don't need to call ```rebuild!```.

## Usage

### Creation

Create a root node:

  ```ruby
  grandparent = Tag.create!(:name => 'Grandparent')
  ```

There are two equivalent ways to add children. Either use the ```add_child``` method:

  ```ruby
  parent = Tag.create!(:name => 'Parent')
  grandparent.add_child parent
  ```

Or append to the ```children``` collection:

  ```ruby
  child = Tag.create!(:name => 'Child')
  parent.children << child
  ```
  
Then:

  ```ruby
  puts grandparent.self_and_descendants.collect{ |t| t.name }.join(" > ")
  "grandparent > parent > child"

  child.ancestry_path
  ["grandparent", "parent", "child"]
  ```

### +find_or_create_by_path+

We can do all the node creation and add_child calls from the prior section with one method call:

  ```ruby
  child = Tag.find_or_create_by_path "grandparent", "parent", "child"
  ```

You can ```find``` as well as ```find_or_create``` by "ancestry paths". Ancestry paths may be built using any column in your model. The default column is ```name```, which can be changed with the :name_column option provided to ```acts_as_tree```.

Note that the other columns will be null if nodes are created, other than auto-generated columns like ID and created_at timestamp. Only the specified column will receive the path element value.

## Accessing Data

### Class methods

* ``` Tag.root``` returns an arbitrary root node
* ``` Tag.roots``` returns all root nodes
* ``` Tag.leaves``` returns all leaf nodes

### Instance methods

* ``` tag.root``` returns the root for this node
* ``` tag.root?``` returns true if this is a root node
* ``` tag.child?``` returns true if this is a child node. It has a parent.
* ``` tag.leaf?``` returns true if this is a leaf node. It has no children.
* ``` tag.leaves``` returns an array of all the nodes in self_and_descendants that are leaves.
* ``` tag.level``` returns the level, or "generation", for this node in the tree. A root node = 0
* ``` tag.parent``` returns the node's immediate parent
* ``` tag.children``` returns an array of immediate children (just those in the next level).
* ``` tag.ancestors``` returns an array of all parents, parents' parents, etc, excluding self.
* ``` tag.self_and_ancestors``` returns an array of all parents, parents' parents, etc, including self.
* ``` tag.siblings``` returns an array of brothers and sisters (all at that level), excluding self.
* ``` tag.self_and_siblings``` returns an array of brothers and sisters (all at that level), including self.
* ``` tag.descendants``` returns an array of all children, childrens' children, etc., excluding self.
* ``` tag.self_and_descendants``` returns an array of all children, childrens' children, etc., including self.

## Thanks to

* https://github.com/collectiveidea/awesome_nested_set
* https://github.com/patshaughnessy/class_factory
