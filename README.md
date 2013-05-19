# Closure Tree

### Closure_tree lets your ActiveRecord models act as nodes in a [tree data structure](http://en.wikipedia.org/wiki/Tree_%28data_structure%29)

Common applications include modeling hierarchical data, like tags, page graphs in CMSes,
and tracking user referrals.

[![Build Status](https://secure.travis-ci.org/mceachen/closure_tree.png?branch=master)](http://travis-ci.org/mceachen/closure_tree)
[![Gem Version](https://badge.fury.io/rb/closure_tree.png)](http://rubygems.org/gems/closure_tree)

Substantially more efficient than
[ancestry](https://github.com/stefankroes/ancestry) and
[acts_as_tree](https://github.com/amerine/acts_as_tree), and even more
awesome than [awesome_nested_set](https://github.com/collectiveidea/awesome_nested_set/),
closure_tree has some great features:

* __Best-in-class select performance__:
  * Fetch your whole ancestor lineage in 1 SELECT.
  * Grab all your descendants in 1 SELECT.
  * Get all your siblings in 1 SELECT.
  * Fetch all [descendants as a nested hash](#nested-hashes) in 1 SELECT.
  * [Find a node by ancestry path](#find_or_create_by_path) in 1 SELECT.
* __Best-in-class mutation performance__:
  * 2 SQL INSERTs on node creation
  * 3 SQL INSERT/UPDATEs on node reparenting
* Support for reparenting children (and all their progeny)
* Support for [concurrency](#concurrency) (using [with_advisory_lock](https://github/mceachen/with_advisory_lock))
* Support for polymorphism [STI](#sti) within the hierarchy
* ```find_or_create_by_path``` for [building out hierarchies quickly and conveniently](#find_or_create_by_path)
* Support for [deterministic ordering](#deterministic-ordering) of children
* Support for [preordered](http://en.wikipedia.org/wiki/Tree_traversal#Pre-order) traversal of descendants
* Excellent [test coverage](#testing) in a variety of environments

See [Bill Karwin](http://karwin.blogspot.com/)'s excellent
[Models for hierarchical data presentation](http://www.slideshare.net/billkarwin/models-for-hierarchical-data)
for a description of different tree storage algorithms.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Accessing Data](#accessing-data)
- [Polymorphic hierarchies with STI](#polymorphic-hierarchies-with-sti)
- [Deterministic ordering](#deterministic-ordering)
- [Concurrency](#concurrency)
- [FAQ](#faq)
- [Testing](#testing)
- [Change log](#change-log)

## Installation

Note that closure_tree only supports Rails 3.0 and later, and has test coverage for MySQL, PostgreSQL, and SQLite.

1.  Add this to your Gemfile: ```gem 'closure_tree'```

2.  Run ```bundle install```

3.  Add ```acts_as_tree``` to your hierarchical model(s). There are a number of [options](#available-options) you can pass in, too.

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
    "_hierarchies". Note that by calling ```acts_as_tree```, a "virtual model" (in this case, ```TagHierarchy```)
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
    ```parent_id``` column, run ```Tag.rebuild!``` and your
    ```tag_hierarchies``` table will be truncated and rebuilt.

    If you're starting from scratch you don't need to call ```rebuild!```.

## Usage

### Creation

Create a root node:

```ruby
grandparent = Tag.create(:name => 'Grandparent')
```

Child nodes are created by appending to the children collection:

```ruby
parent = grandparent.children.create(:name => 'Parent')
```

Or by appending to the children collection:

```ruby
child2 = Tag.new(:name => 'Second Child')
parent.children << child2
```

Or by calling the "add_child" method:

```ruby
child3 = Tag.new(:name => 'Third Child')
parent.add_child child3
```

Then:

```ruby
grandparent.self_and_descendants.collect(&:name)
=> ["Grandparent", "Parent", "First Child", "Second Child", "Third Child"]

child1.ancestry_path
=> ["Grandparent", "Parent", "First Child"]
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

### Nested hashes

```hash_tree``` provides a method for rendering a subtree as an
ordered nested hash:

```ruby
b = Tag.find_or_create_by_path %w(a b)
a = b.parent
b2 = Tag.find_or_create_by_path %w(a b2)
d1 = b.find_or_create_by_path %w(c1 d1)
c1 = d1.parent
d2 = b.find_or_create_by_path %w(c2 d2)
c2 = d2.parent

Tag.hash_tree
=> {a => {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}, b2 => {}}}

Tag.hash_tree(:limit_depth => 2)
=> {a => {b => {}, b2 => {}}}

b.hash_tree
=> {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}}

b.hash_tree(:limit_depth => 2)
=> {b => {c1 => {}, c2 => {}}}
```

**If your tree is large (or might become so), use :limit_depth.**

Without this option, ```hash_tree``` will load the entire contents of that table into RAM. Your
server may not be happy trying to do this.

HT: [ancestry](https://github.com/stefankroes/ancestry#arrangement) and [elhoyos](https://github.com/mceachen/closure_tree/issues/11)

### <a id="options"></a>Available options

When you include ```acts_as_tree``` in your model, you can provide a hash to override the following defaults:

* ```:parent_column_name``` to override the column name of the parent foreign key in the model's table. This defaults to "parent_id".
* ```:hierarchy_table_name``` to override the hierarchy class name. This defaults to the singular name of the model + "Hierarchy", like ```TagHierarchy```.
* ```:hierarchy_table_name``` to override the hierarchy table name. This defaults to the singular name of the model + "_hierarchies", like ```tag_hierarchies```.
* ```:dependent``` determines what happens when a node is destroyed. Defaults to ```nullify```.
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
* ```Tag.hash_tree``` returns an [ordered, nested hash](#nested-hashes) that can be depth-limited.
* ```Tag.find_by_path(path)``` returns the node whose name path is ```path```. See (#find_or_create_by_path).
* ```Tag.find_or_create_by_path(path)``` returns the node whose name path is ```path```, and will create the node if it doesn't exist already.See (#find_or_create_by_path).
* ```Tag.find_all_by_generation(generation_level)``` returns the descendant nodes who are ```generation_level``` away from a root. ```Tag.find_all_by_generation(0)``` is equivalent to ```Tag.roots```.

### Instance methods

* ```tag.root``` returns the root for this node
* ```tag.root?``` returns true if this is a root node
* ```tag.child?``` returns true if this is a child node. It has a parent.
* ```tag.leaf?``` returns true if this is a leaf node. It has no children.
* ```tag.leaves``` is scoped to all leaf nodes in self_and_descendants.
* ```tag.depth``` returns the depth, or "generation", for this node in the tree. A root node will have a value of 0.
* ```tag.parent``` returns the node's immediate parent. Root nodes will return nil.
* ```tag.children``` is a ```has_many``` of immediate children (just those nodes whose parent is the current node).
* ```tag.child_ids``` is an array of the IDs of the children.
* ```tag.ancestors``` is a ordered scope of [ parent, grandparent, great grandparent, … ]. Note that the size of this array will always equal ```tag.depth```.
* ```tag.ancestor_ids``` is an array of the IDs of the ancestors.
* ```tag.self_and_ancestors``` returns a scope containing self, parent, grandparent, great grandparent, etc.
* ```tag.siblings``` returns a scope containing all nodes with the same parent as ```tag```, excluding self.
* ```tag.sibling_ids``` returns an array of the IDs of the siblings.
* ```tag.self_and_siblings``` returns a scope containing all nodes with the same parent as ```tag```, including self.
* ```tag.descendants``` returns a scope of all children, childrens' children, etc., excluding self ordered by depth.
* ```tag.descendant_ids``` returns an array of the IDs of the descendants.
* ```tag.self_and_descendants``` returns a scope of all children, childrens' children, etc., including self, ordered by depth.
* ```tag.hash_tree``` returns an [ordered, nested hash](#nested-hashes) that can be depth-limited.
* ```tag.find_by_path(path)``` returns the node whose name path *from ```tag```* is ```path```. See (#find_or_create_by_path).
* ```tag.find_or_create_by_path(path)``` returns the node whose name path *from ```tag```* is ```path```, and will create the node if it doesn't exist already.See (#find_or_create_by_path).
* ```tag.find_all_by_generation(generation_level)``` returns the descendant nodes who are ```generation_level``` away from ```tag```.
    * ```tag.find_all_by_generation(0).to_a``` == ```[tag]```
    * ```tag.find_all_by_generation(1)``` == ```tag.children```
    * ```tag.find_all_by_generation(2)``` will return the tag's grandchildren, and so on.
* ```tag.destroy``` will destroy a node and do <em>something</em> to its children, which is determined by the ```:dependent``` option passed to ```acts_as_tree```.

## Polymorphic hierarchies with STI

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

Please note that Rails (<= 3.2) doesn't handle polymorphic associations correctly if
you use the ```:type``` attribute, so **this doesn't work**:

```ruby
# BAD: ActiveRecord ignores the :type attribute:
root.children.create(:name => "child", :type => "WhenTag")
```

Instead, use either ```.add_child``` or ```children <<```:

```ruby
# GOOD!
a = Tag.create!(:name => "a")
b = WhenTag.new(:name => "b")
a.children << b
c = WhatTag.new(:name => "c")
b.add_child(c)
```

See [issue 43](https://github.com/mceachen/closure_tree/issues/43) for more information.

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

* The class method ```#roots_and_descendants_preordered```, which returns all nodes in your tree,
  [pre-ordered](http://en.wikipedia.org/wiki/Tree_traversal#Pre-order).

* ```node1.self_and_descendants_preordered``` which will return descendants,
  [pre-ordered](http://en.wikipedia.org/wiki/Tree_traversal#Pre-order).

* ```node1.prepend_sibling(node2)``` which will
  1. set ```node2``` to the same parent as ```node1```,
  2. set ```node2```'s order column to 1 less than ```node1```'s value, and
  3. decrement the order_column of all children of node1's parents whose order_column is <>>= node2's new value by 1.

* ```node1.append_sibling(node2)``` which will
  1. set ```node2``` to the same parent as ```node1```,
  2. set ```node2```'s order column to 1 more than ```node1```'s value, and
  3. increment the order_column of all children of node1's parents whose order_column is >= node2's new value by 1.

```ruby

root = OrderedTag.create(:name => "root")
a = OrderedTag.create(:name => "a", :parent => "root")
b = OrderedTag.create(:name => "b")
c = OrderedTag.create(:name => "c")

# We have to call 'root.reload.children' because root won't be in sync with the database otherwise:

a.append_sibling(b)
root.reload.children.collect(&:name)
=> ["a", "b"]

a.prepend_sibling(b)
root.reload.children.collect(&:name)
=> ["b", "a"]

a.append_sibling(c)
root.reload.children.collect(&:name)
=> ["b", "a", "c"]

b.append_sibling(c)
root.reload.children.collect(&:name)
=> ["b", "c", "a"]
```

## Concurrency

Several methods, especially ```#rebuild``` and ```#find_or_create_by_path```, cannot run concurrently correctly.
```#find_or_create_by_path```, for example, may create duplicate nodes.

Database row-level locks work correctly with PostgreSQL, but MySQL's row-level locking is broken, and
erroneously reports deadlocks where there are none. To work around this, and have a consistent implementation
for both MySQL and PostgreSQL, [with_advisory_lock](https://github.com/mceachen/with_advisory_lock)
is used automatically to ensure correctness.

If you are already managing concurrency elsewhere in your application, and want to disable the use
of with_advisory_lock, pass ```:with_advisory_lock => false``` in the options hash:

```ruby
class Tag
  acts_as_tree :with_advisory_lock => false
end
```

Note that you *will eventually have data corruption* if you disable advisory locks, write to your
database with multiple threads, and don't provide an alternative mutex.


## FAQ

### Does this gem support multiple parents?

No. This gem's API is based on the assumption that each node has either 0 or 1 parent.

The underlying closure tree structure will support multiple parents, but there would be many
breaking-API changes to support it. I'm open to suggestions and pull requests.

### How do I use this with test fixtures?

Test fixtures aren't going to be running your ```after_save``` hooks after inserting all your
fixture data, so you need to call ```.rebuild!``` before your test runs. There's an example in
the spec ```tag_spec.rb```:

```ruby
  describe "Tag with fixtures" do
    fixtures :tags
    before :each do
      Tag.rebuild! # <- required if you use fixtures
    end
```

**However, if you're just starting with Rails, may I humbly suggest you adopt a factory library**,
rather than using fixtures? [Lots of people have written about this already](https://www.google.com/search?q=fixtures+versus+factories).


## Testing

Closure tree is [tested under every combination](http://travis-ci.org/#!/mceachen/closure_tree) of

* Ruby 1.8.7 and Ruby 1.9.3
* The latest Rails 3.0, 3.1, and 3.2 branches, and
* MySQL and PostgreSQL. SQLite works in a single-threaded environment.

Assuming you're using [rbenv](https://github.com/sstephenson/rbenv), you can use ```tests.sh``` to
run the test matrix locally.

Parallelism is not tested with Rails 3.0.x nor 3.1.x due to this
[known issue](https://github.com/rails/rails/issues/7538).

## Change log

### 4.0.1

* Numeric, deterministically ordered siblings will always be [0..#{self_and_siblings.count}]
  (previously, the sort order might use negative values, which broke the preordering).
  Resolves [issue 49](https://github.com/mceachen/closure_tree/issues/49). Thanks for the help,
  [Leonel Galan](https://github.com/leonelgalan), [Juan Hoyos](https://github.com/elhoyos), and
  [Michael Elfassy](https://github.com/elfassy)!

* The ```order``` option can be a symbol now. Resolves [issue 46](https://github.com/mceachen/closure_tree/issues/46).

### 4.0.0

* Moved all of closure_tree's implementation-detail methods into a ```ClosureTree::Support```
  instance, which removes almost all of the namespace pollution in your models that wasn't
  for normal consumption. If you were using any of these methods, they're now available through
  the "_ct" class and instance member.

  *This change may break consumers*, so I incremented the major version number, even though no new
  functionality was released.

### 3.10.2

* Prevent faulty SQL statement when ```#siblings``` is called on an unsaved records.
  Resolves [issue 52](https://github.com/mceachen/closure_tree/pull/52). Perfect pull
  request by [Gary Greyling](https://github.com/garygreyling).

* The ```.roots``` class method now correctly respects the ```:order``` option.
  Resolves [issue 53](https://github.com/mceachen/closure_tree/issues/53).
  Thanks for finding this, [Brendon Muir](https://github.com/brendon)!

### 3.10.1

* Multipart constant names like "Admin::PageHierarchy" are now supported.
  Resolves [issue 47](https://github.com/mceachen/closure_tree/issues/47).
  Thanks for the perfect pull request, [Simon Menke](https://github.com/fd)!

* Committing transactions involving large numbers of hierarchy model classes was very slow due
  to hash collisions in the hierarchy class. A better hash implementation addressed
  [issue 48](https://github.com/mceachen/closure_tree/issues/48).
  Thanks, [Joel Turkel](https://github.com/jturkel)!

### 3.10.0

* Added ```#roots_and_descendants_preordered```.
  Thanks for the suggestion, [Leonel Galan](https://github.com/leonelgalan)!

### 3.9.0

* Added ```.child_ids```.
* Removed ```dependent => destroy``` on the descendant_hierarchy and ancestor_hierarchy collections
  (they were a mistake).
* Clarified documentation for creation and child associations.
  Because ```Tag.create!(:parent => ...)``` requires a ```.reload```, I removed it as an example.

All three of these improvements were suggested by Andrew Bromwich. Thanks!

### 3.8.2

* find_by_path uses 1 SELECT now. BOOM.

### 3.8.1

* Double-check locking for find_or_create_by_path

### 3.8.0

* Support for preordered descendants. This requires a numeric sort order column.
  Resolves [feature request 38](https://github.com/mceachen/closure_tree/issues/38).
* Moved modules from ```acts_as_tree``` into separate files

### 3.7.3

Due to MySQL's inability to lock rows properly, I've switched to advisory_locks for
all write paths. This will prevent deadlocks, addressing
[issue 41](https://github.com/mceachen/closure_tree/issues/41).

### 3.7.2

* Support for UUID primary keys. Addresses
  [issue 40](https://github.com/mceachen/closure_tree/issues/40). Thanks for the pull request,
  [Julien](https://github.com/calexicoz)!

### 3.7.1

* Moved requires into ActiveSupport.on_load
* Added ```require 'with_advisory_lock'```

### 3.7.0

**Thread safety!**
* [Advisory locks](https://github.com/mceachen/with_advisory_lock) were
  integrated with the class-level ```find_or_create_by_path``` and ```rebuild!```.
* Pessimistic locking is used by the instance-level ```find_or_create_by_path```.

### 3.6.9

* [Don Morrison](https://github.com/elskwid) massaged the [#hash_tree](#nested-hashes) query to
be more efficient, and found a bug in ```hash_tree```'s query that resulted in duplicate rows,
wasting time on the ruby side.

### 3.6.7

* Added workaround for ActiveRecord::Observer usage pre-db-creation. Addresses
  [issue 32](https://github.com/mceachen/closure_tree/issues/32).
  Thanks, [Don Morrison](https://github.com/elskwid)!

### 3.6.6

* Added support for Rails 4's [strong parameter](https://github.com/rails/strong_parameters).
Thanks, [James Miller](https://github.com/bensie)!

### 3.6.5

* Use ```quote_table_name``` instead of ```quote_column_name```. Addresses
 [issue 29](https://github.com/mceachen/closure_tree/issues/29). Thanks,
 [Marcello Barnaba](https://github.com/vjt)!

### 3.6.4

* Use ```.pluck``` when available for ```.ids_from```. Addresses
 [issue 26](https://github.com/mceachen/closure_tree/issues/26). Thanks,
 [Chris Sturgill](https://github.com/sturgill)!

### 3.6.3

* Fixed [issue 24](https://github.com/mceachen/closure_tree/issues/24), which optimized ```#hash_tree```
  for roots. Thanks, [Saverio Trioni](https://github.com/rewritten)!

### 3.6.2

* Fixed [issue 23](https://github.com/mceachen/closure_tree/issues/23), which added support for ```#siblings```
  when sort_order wasn't specified. Thanks, [Gary Greyling](https://github.com/garygreyling)!

### 3.6.1

* Fixed [issue 20](https://github.com/mceachen/closure_tree/issues/20), which affected
  deterministic ordering when siblings where different STI classes. Thanks, [edwinramirez](https://github.com/edwinramirez)!

### 3.6.0

Added support for:
* ```:hierarchy_class_name``` as an option
* ActiveRecord::Base.table_name_prefix
* ActiveRecord::Base.table_name_suffix

This addresses [issue 21](https://github.com/mceachen/closure_tree/issues/21). Thanks, [Judd Blair](https://github.com/juddblair)!

### 3.5.2

* Added ```find_all_by_generation```
  for [feature request 17](https://github.com/mceachen/closure_tree/issues/17).

### 3.4.2

* Fixed [issue 18](https://github.com/mceachen/closure_tree/issues/18), which affected
  append_node/prepend_node ordering when the first node didn't have an explicit order_by value

### 3.4.1

* Reverted .gemspec mistake that changed add_development_dependency to add_runtime_dependency

### 3.4.0

Fixed [issue 15](https://github.com/mceachen/closure_tree/issues/15):
* "parent" is now attr_accessible, which adds support for constructor-provided parents.
* updated readme accordingly

### 3.3.2

* Merged calebphillips' patch for a more efficient leaves query

### 3.3.1

* Added support for partially-unsaved hierarchies [issue 13](https://github.com/mceachen/closure_tree/issues/13):
```
a = Tag.new(name: "a")
b = Tag.new(name: "b")
a.children << b
a.save
```

### 3.3.0

* Added [```hash_tree```](#nested-hashes).

### 3.2.1

* Added ```ancestor_ids```, ```descendant_ids```, and ```sibling_ids```
* Added example spec to solve [issue 9](https://github.com/mceachen/closure_tree/issues/9)

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
* JetBrains, which provides an [open-source license](http://www.jetbrains.com/ruby/buy/buy.jsp#openSource) to
  [RubyMine](http://www.jetbrains.com/ruby/features/) for the development of this project.
