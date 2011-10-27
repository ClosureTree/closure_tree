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

3.  Add ```acts_as_tree``` to your hierarchical model(s) (see the <em>Available options</em> section below for details).

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
      class CreateTagHierarchies < ActiveRecord::Migration
        def change
          create_table :tag_hierarchies, :id => false do |t|
            t.integer  :ancestor_id, :null => false   # ID of the parent/grandparent/great-grandparent/... tag
            t.integer  :descendant_id, :null => false # ID of the target tag
            t.integer  :generations, :null => false   # Number of generations between the ancestor and the descendant. Parent/child = 1, for example.
          end

          # For "all progeny of..." selects:
          add_index :tag_hierarchies, [:ancestor_id, :descendant_id], :unique => true

          # For "all ancestors of..." selects
          add_index :tag_hierarchies, [:descendant_id]
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

### <code>find_or_create_by_path</code>

We can do all the node creation and add_child calls from the prior section with one method call:

  ```ruby
  child = Tag.find_or_create_by_path "grandparent", "parent", "child"
  ```

You can ```find``` as well as ```find_or_create``` by "ancestry paths". Ancestry paths may be built using any column in your model. The default column is ```name```, which can be changed with the :name_column option provided to ```acts_as_tree```.

Note that the other columns will be null if nodes are created, other than auto-generated columns like ID and created_at timestamp. Only the specified column will receive the path element value.

### Available options
<a id="options" />

When you include ```acts_as_tree``` in your model, you can provide a hash to override the following defaults:

* ```:parent_column_name``` to override the column name of the parent foreign key in the model's table. This defaults to "parent_id".
* ```:hierarchy_table_name``` to override the hierarchy table name. This defaults to the singular name of the model + "_hierarchies".
* ```:dependent``` determines what happens when a node is destroyed. Defaults to ```nil```.
    * ```:nullify``` will simply set the parent column to null. Each child node will be considered a "root" node. This is the default.
    * ```:delete_all``` will delete all descendant nodes (which circumvents the destroy hooks)
    * ```:destroy``` will destroy all descendant nodes (which runs the destroy hooks on each child node)
* ```:name_column``` used by #```find_or_create_by_path```, #```find_by_path```, and ```ancestry_path``` instance methods. This is primarily useful if the model only has one required field (like a "tag").

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
* ``` tag.level``` returns the level, or "generation", for this node in the tree. A root node == 0.
* ``` tag.parent``` returns the node's immediate parent. Root nodes will return nil.
* ``` tag.children``` returns an array of immediate children (just those nodes whose parent is the current node).
* ``` tag.ancestors``` returns an array of [ parent, grandparent, great grandparent, ... ]. Note that the size of this array will always equal ```tag.level```.
* ``` tag.self_and_ancestors``` returns an array of self, parent, grandparent, great grandparent, etc.
* ``` tag.siblings``` returns an array of brothers and sisters (all at that level), excluding self.
* ``` tag.self_and_siblings``` returns an array of brothers and sisters (all at that level), including self.
* ``` tag.descendants``` returns an array of all children, childrens' children, etc., excluding self.
* ``` tag.self_and_descendants``` returns an array of all children, childrens' children, etc., including self.
* ``` tag.reparent``` lets you move a node (and all it's children) to a new parent.
* ``` tag.destroy``` will destroy a node as well as possibly all of its children. See the ```:dependent``` option passed to ```acts_as_tree```.

## Changelog

### 2.0.0.beta1

* Had to increment the major version, as rebuild! will need to be called by prior consumers to support the new ```leaves``` class and instance methods.
* Tag deletion is supported now along with ```:dependent => :destroy``` and ```:dependent => :delete_all```
* Added new instance method ```reparent```
* Switched from default rails plugin directory structure to rspec

## Thanks to

* https://github.com/collectiveidea/awesome_nested_set
* https://github.com/patshaughnessy/class_factory
