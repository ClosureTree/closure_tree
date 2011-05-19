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

1.  Add this to your Gemfile:

        gem 'closure-tree'

2.  Run

        bundle install

3.  Add ```acts_as_closure_tree``` to your hierarchical model(s).

4.  Add a database migration to store the hierarchy for your model. By
    convention the table name will be the model's table name, followed by
    "_hierarchy":

    ```ruby
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
    ```

5.  Remember to ```rake db:migrate```


## Usage

It's just like your old friend, but less geriatric.

(Based on [Bear Den Design's post](http://beardendesigns.com/blogs/permalink/56))

### Creation

Create a root node:

```ruby
science = Category.create!(:name => 'Science')
```

Put a new thing inside this root node:

```ruby
physics = Category.create!(:name => 'Physics')
physics.move_to_child_of(science)
```

Put another thing inside the "physics" node:

```ruby
gravity = Category.create!(:name => ‘Gravity’)
gravity.move_to_child_of(physics)
```

Reload the root node:

```ruby
science.reload
```

Now you should have something that resembles this:

1.  science
    1.  physics
        1. gravity


### Advanced Usage

Accessing levels without a hit to the db:

```ruby
Category.each_with_level(Category.root.self_and_descendants) do |category, level|
  ...
end
```

## Accessing Data

### Class methods

* ```Category.root``` returns an arbitrary root node
* ```Category.roots``` returns all root nodes

### Instance methods

* ```my_cat.root``` returns the root for this node
* ```my_cat.level``` returns the level, or "generation", for this node in the tree. A root node = 0
* ```my_cat.parent``` returns the node's immediate parent
* ```my_cat.children``` returns an array of immediate children (just those in the next level).
* ```my_cat.ancestors``` returns an array of all parents, parents' parents, etc, excluding self.
* ```my_cat.self_and_ancestors``` returns an array of all parents, parents' parents, etc, including self.
* ```my_cat.siblings``` returns an array of brothers and sisters (all at that level), excluding self.
* ```my_cat.self_and_siblings``` returns an array of brothers and sisters (all at that level), including self.
* ```my_cat.descendants``` returns an array of all children, childrens' children, etc., excluding self.
* ```my_cat.self_and_descendants``` returns an array of all children, childrens' children, etc., including self.
* ```my_cat.leaves``` returns an array of all descendants that have no children.

 ### Instance methods: Predicates (these don't need to hit the DB to respond)

* ```my_cat.root?``` returns  true if this is a root node
* ```my_cat.child?``` returns  true if this is a child node. It has a parent.
* ```my_cat.is_ancestor_of?(obj)``` returns  true if nested by any obj
* ```my_cat.is_or_is_ancestor_of?(obj)``` returns  true if nested by any obj or self is obj
* ```my_cat.is_descendant_of?(obj)``` returns  true if self is nested under obj
* ```my_cat.is_or_is_descendant_of?(obj)``` returns  true if self is nested under obj or self is obj
* ```my_cat.leaf?``` returns  true if this is a leaf node. It has no children.
