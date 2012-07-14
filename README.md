# Closure Tree [![Build Status](https://secure.travis-ci.org/mceachen/closure_tree.png?branch=master)](http://travis-ci.org/mceachen/closure_tree)

Closure Tree is a mostly-API-compatible replacement for the
[ancestry](https://github.com/stefankroes/ancestry),
[acts_as_tree](https://github.com/amerine/acts_as_tree) and
[awesome_nested_set](https://github.com/collectiveidea/awesome_nested_set/) gems, giving you:

* Much better mutation performance thanks to the Closure Tree storage algorithm
* Very efficient select performance (again, thanks to Closure Tree)
* Efficient subtree selects
* Support for polymorphism [STI](#sti) within the hierarchy
* ```find_or_create_by_path``` for [building out hierarchies quickly and conveniently](#find_or_create_by_path)
* Support for [deterministic ordering](#deterministic-ordering) of children
* Excellent [test coverage](#testing) in a variety of environments

See [Bill Karwin](http://karwin.blogspot.com/)'s excellent
[Models for hierarchical data presentation](http://www.slideshare.net/billkarwin/models-for-hierarchical-data)
for a description of different tree storage algorithms.

## Installation

Note that closure_tree only supports Rails 3.0 and later, and has test coverage for MySQL, PostgreSQL, and SQLite.

1.  Add this to your Gemfile: ```gem 'closure_tree'```

2.  Run ```bundle install```

3.  Add ```acts_as_tree``` to your hierarchical model(s) (see the <em>Available options</em> section below for details).

4.  Add a migration to add a ```parent_id``` column to the model you want to act_as_tree.
    You may want to also [add a column for deterministic ordering of children](#sort_order), but that's optional.

    ```ruby
    class AddParentIdToTag < ActiveRecord::Migration
      def change
        add_column :tag, :parent_id, :integer
      end
    end
    ```

    Note that if the column is null, the tag will be considered a root node.

5.  Add a database migration to store the hierarchy for your model. By
    default the table name will be the model's table name, followed by
    "_hierarchies". Note that by calling ```acts_as_tree```, a "virtual model" (in this case, ```TagsHierarchy```)
    will be added automatically, so you don't need to create it.

    ```ruby
    class CreateTagHierarchies < ActiveRecord::Migration
      def change
        create_table :tag_hierarchies, :id => false do |t|
          t.integer  :ancestor_id, :null => false   # ID of the parent/grandparent/great-grandparent/... tag
          t.integer  :descendant_id, :null => false # ID of the target tag
          t.integer  :generations, :null => false   # Number of generations between the ancestor and the descendant. Parent/child = 1, for example.
        end

        # For "all progeny of…" selects:
        add_index :tag_hierarchies, [:ancestor_id, :descendant_id], :unique => true

        # For "all ancestors of…" selects
        add_index :tag_hierarchies, [:descendant_id]
      end
    end
    ```

6.  Run ```rake db:migrate```

7.  If you're migrating from another system where your model already has a
    ```parent_id``` column, run ```Tag.rebuild!``` and the
    …_hierarchy table will be truncated and rebuilt.

    If you're starting from scratch you don't need to call ```rebuild!```.

## Usage

### Creation

Create a root node:

```ruby
grandparent = Tag.create(:name => 'Grandparent')
```

Child nodes are created by appending to the children collection:

```ruby
child = parent.children.create(:name => 'Child')
```

You can also append to the children collection:

```ruby
child = Tag.create(:name => 'Child')
parent.children << child
```

Or call the "add_child" method:

```ruby
parent = Tag.create(:name => 'Parent')
grandparent.add_child parent
```

Then:

```ruby
puts grandparent.self_and_descendants.collect{ |t| t.name }.join(" > ")
=> "grandparent > parent > child"

child.ancestry_path
=> ["grandparent", "parent", "child"]
```

### find_or_create_by_path

We can do all the node creation and add_child calls with one method call:

  ```ruby
  child = Tag.find_or_create_by_path(["grandparent", "parent", "child"])
  ```

You can ```find``` as well as ```find_or_create``` by "ancestry paths".
Ancestry paths may be built using any column in your model. The default
column is ```name```, which can be changed with the :name_column option
provided to ```acts_as_tree```.

Note that any other AR fields can be set with the second, optional ```attributes``` argument.

```ruby
child = Tag.find_or_create_by_path(%w{home chuck Photos"}, {:tag_type => "File"})
```
This will pass the attribute hash of ```{:name => "home", :tag_type => "File"}``` to
```Tag.find_or_create_by_name``` if the root directory doesn't exist (and
```{:name => "chuck", :tag_type => "File"}``` if the second-level tag doesn't exist, and so on).

### Moving nodes around the tree

Nodes can be moved around to other parents, and closure_tree moves the node's descendancy to the new parent for you:

```ruby
d = Tag.find_or_create_by_path %w(a b c d)
h = Tag.find_or_create_by_path %w(e f g h)
e = h.root
d.add_child(e) # "d.children << e" would work too, of course
h.ancestry_path
=> ["a", "b", "c", "d", "e", "f", "g", "h"]
```

### <a id="options"></a>Available options

When you include ```acts_as_tree``` in your model, you can provide a hash to override the following defaults:

* ```:parent_column_name``` to override the column name of the parent foreign key in the model's table. This defaults to "parent_id".
* ```:hierarchy_table_name``` to override the hierarchy table name. This defaults to the singular name of the model + "_hierarchies".
* ```:dependent``` determines what happens when a node is destroyed. Defaults to ```nil```.
    * ```:nullify``` will simply set the parent column to null. Each child node will be considered a "root" node. This is the default.
    * ```:delete_all``` will delete all descendant nodes (which circumvents the destroy hooks)
    * ```:destroy``` will destroy all descendant nodes (which runs the destroy hooks on each child node)
* ```:name_column``` used by #```find_or_create_by_path```, #```find_by_path```, and ```ancestry_path``` instance methods. This is primarily useful if the model only has one required field (like a "tag").
* ```:order``` used to set up [deterministic ordering](#deterministic-ordering)

## Accessing Data

### Class methods

* ```Tag.root``` returns an arbitrary root node
* ```Tag.roots``` returns all root nodes
* ```Tag.leaves``` returns all leaf nodes

### Instance methods

* ```tag.root``` returns the root for this node
* ```tag.root?``` returns true if this is a root node
* ```tag.child?``` returns true if this is a child node. It has a parent.
* ```tag.leaf?``` returns true if this is a leaf node. It has no children.
* ```tag.leaves``` is scoped to all leaf nodes in self_and_descendants.
* ```tag.depth``` returns the depth, or "generation", for this node in the tree. A root node will have a value of 0.
* ```tag.parent``` returns the node's immediate parent. Root nodes will return nil.
* ```tag.children``` is a ```has_many``` of immediate children (just those nodes whose parent is the current node).
* ```tag.ancestors``` is a ordered scope of [ parent, grandparent, great grandparent, … ]. Note that the size of this array will always equal ```tag.depth```.
* ```tag.self_and_ancestors``` returns a scope containing self, parent, grandparent, great grandparent, etc.
* ```tag.siblings``` returns a scope containing all nodes with the same parent as ```tag```, excluding self.
* ```tag.self_and_siblings``` returns a scope containing all nodes with the same parent as ```tag```, including self.
* ```tag.descendants``` returns a scope of all children, childrens' children, etc., excluding self ordered by depth.
* ```tag.self_and_descendants``` returns a scope of all children, childrens' children, etc., including self, ordered by depth.
* ```tag.destroy``` will destroy a node and do <em>something</em> to its children, which is determined by the ```:dependent``` option passed to ```acts_as_tree```.

## <a id="sti"></a>Polymorphic hierarchies with STI

Polymorphic models using single table inheritance (STI) are supported:

1. Create a db migration that adds a String ```type``` column to your model
2. Subclass the model class. You only need to add ```acts_as_tree``` to your base class:

```ruby
class Tag < ActiveRecord::Base
  acts_as_tree
end
class WhenTag < Tag ; end
class WhereTag < Tag ; end
class WhatTag < Tag ; end
```

## Deterministic ordering

By default, children will be ordered by your database engine, which may not be what you want.

If you want to order children alphabetically, and your model has a ```name``` column, you'd do this:

```ruby
class Tag < ActiveRecord::Base
  acts_as_tree :order => 'name'
end
```

If you want a specific order, add a new integer column to your model in a migration:

```ruby
t.integer :sort_order
```

and in your model:

```ruby
class OrderedTag < ActiveRecord::Base
  acts_as_tree :order => 'sort_order'
end
```

When you enable ```order```, you'll also have the following new methods injected into your model:

* ```tag.siblings_before``` is a scope containing all nodes with the same parent as ```tag```,
  whose sort order column is less than ```self```. These will be ordered properly, so the ```last```
  element in scope will be the sibling immediately before ```self```
* ```tag.siblings_after``` is a scope containing all nodes with the same parent as ```tag```,
  whose sort order column is more than ```self```. These will be ordered properly, so the ```first```
  element in scope will be the sibling immediately "after" ```self```

If your ```order``` column is an integer attribute, you'll also have these:

* ```tag.add_sibling_before(sibling_node)``` which will
  1. move ```tag``` to the same parent as ```sibling_node```,
  2. decrement the sort_order values of the nodes before the ```sibling_node``` by one, and
  3. set ```tag```'s order column to 1 less than the ```sibling_node```'s value.

* ```tag.add_sibling_after(sibling_node)``` which will
  1. move ```tag``` to the same parent as ```sibling_node```,
  2. increment the sort_order values of the nodes after the ```sibling_node``` by one, and
  3. set ```tag```'s order column to 1 more than the ```sibling_node```'s value.

```ruby
root = OrderedTag.create(:name => "root")
a = OrderedTag.create(:name => "a", :parent => "root")
b = OrderedTag.create(:name => "b")
c = OrderedTag.create(:name => "c")

a.append_sibling(b)
root.children.collect(&:name)
=> ["a", "b"]

a.prepend_sibling(b)
root.children.collect(&:name)
=> ["b", "a"]

a.append_sibling(c)
root.children.collect(&:name)
=> ["a", "c", "b"]

b.append_sibling(c)
root.children.collect(&:name)
=> ["a", "b", "c"]
```

## Testing

Closure tree is [tested under every combination](https://secure.travis-ci.org/mceachen/closure_tree.png?branch=master) of

* Ruby 1.8.7 and Ruby 1.9.3
* The latest Rails 3.0, 3.1, and 3.2 branches, and
* MySQL, PostgreSQL, and SQLite.


## Change log

### 3.2.0

* Added support for deterministic ordering of nodes.

### 3.1.0

* Switched to using ```has_many :though``` rather than ```has_and_belongs_to_many```

### 3.0.4

* Merged [pull request](https://github.com/mceachen/closure_tree/pull/8) to fix ```.siblings``` and ```.self_and_siblings```
  (Thanks, [eljojo](https://github.com/eljojo)!)

### 3.0.3

* Added support for ActiveRecord's whitelist_attributes
  (Make sure you read [the Rails Security Guide](http://guides.rubyonrails.org/security.html), and
  enable ```config.active_record.whitelist_attributes``` in your ```config/application.rb``` ASAP!)

### 3.0.2

* Fix for ancestry-loop detection (performed by a validation, not through raising an exception in before_save)

### 3.0.1

* Support 3.2.0's fickle deprecation of InstanceMethods (Thanks, [jheiss](https://github.com/mceachen/closure_tree/pull/5))!

### 3.0.0

* Support for polymorphic trees
* ```find_by_path``` and ```find_or_create_by_path``` signatures changed to support constructor attributes
* tested against Rails 3.1.3

### 2.0.0

* Had to increment the major version, as rebuild! will need to be called by prior consumers to support the new ```leaves``` class and instance methods.
* Tag deletion is supported now along with ```:dependent => :destroy``` and ```:dependent => :delete_all```
* Switched from default rails plugin directory structure to rspec
* Support for running specs under different database engines: ```export DB ; for DB in sqlite3 mysql postgresql ; do rake ; done```

## Thanks to

* https://github.com/collectiveidea/awesome_nested_set
* https://github.com/patshaughnessy/class_factory
