# Changelog

### 5.2.0

* [Eduardo Turiño](https://github.com/eturino) renamed `acts_as_tree` to `has_closure_tree`. We'll
  keep both annotations around for the forseeable future, but I think not name-colliding by default is
  strictly better. (Thanks for both the suggestion and PR!)
* [Ryan Selk](https://github.com/rselk) made several enhancements to the migration generation (thanks!).
* [ruok5](https://github.com/ruok5) updated the README to clarify a heirarchy maintenance usecase. Thanks!
* Made migrations error with a helpful message if the target didn't have the `has_closure_tree` or
  `acts_as_tree` annotation. This addresses [issue 131](https://github.com/mceachen/closure_tree/issues/131).

### 5.1.1

* Fixed bug in `rails g closure_tree:migration` (introduced by me, not by seuros!) 
  that was reported and fixed by [Rich Kuo](https://github.com/richkuo). Thanks!

### 5.1.0

* [Abdelkader Boudih](https://github.com/seuros) added a database generator
  for the hierarchies table. Thanks!
* [Jason Weathered](https://github.com/jasoncodes) fixed [issue #117](https://github.com/mceachen/closure_tree/pull/117)
  with the preordered traversal code that assumed the primary key column was called `id`. Thanks!

### 5.0.0

#### Breaking API changes

* `find_by_path` and `find_or_create_by_path` now takes either an array of strings 
  or an array of attribute hashes, which can include the inheritance column for STI support.
* Removed the extraneous `base_class` `acts_as_tree` option—it needlessly duplicated ActiveRecord's method.
* Removed the unused `name` `acts_as_tree` option.

#### Improvements and bugfixes

* Cleaned up the inheritance support methods to delegate correctly to ActiveRecord
* Fixed a query generation error when ancestor paths exceeded 50 items.
* Documented the `.touch` option

### 4.6.3

* More goodness from [Abdelkader Boudih](https://github.com/seuros), including rspec 3 support.

### 4.6.2

* Pulled in [106](https://github.com/mceachen/closure_tree/pull/106) which fixed a bug introduced
  in 4.6.0 which broke if the numeric ordering column wasn't named 'sort_order'. Tests have been
  added. Thanks for the fix, [Fission Xuiptz](https://github.com/fissionxuiptz)!

### 4.6.1

* Address [issue 60](https://github.com/mceachen/closure_tree/issues/60) (use `.empty?` rather 
  than `.nil?`—thanks for the suggestion, [Leonel Galán](https://github.com/leonelgalan),
  [Doug Mayer](https://github.com/doxavore) and [Samnang Chhun](https://github.com/samnang)!

### 4.6.0

* Deterministically ordered trees are guaranteed to have a sort_order now.

  **This may be a breaking change if you're expecting sort_order to be nullable.**

  Many thanks to [David Schmidt](https://github.com/inetdavid) for raising and
  working on the issue!

* Added ```append_child``` and ```prepend_child```

* All raw SQL is now ```strip_heredoc```'ed

### 4.5.0

* Merged a bunch of great changes from [Abdelkader Boudih](https://github.com/seuros), 
  including a change to use [appraisal](https://github.com/thoughtbot/appraisal)
* Added Travis builds for Rails 4.1.1 and Ruby 2.1.2
* Dropped support for Rails 3.1, as it is no longer receiving security patches.
  See http://rubyonrails.org/security/ for more information.

### 4.4.0

* Added ```.self_and_descendant_ids``` and ```.self_and_ancestors_ids``` from [PR92](https://github.com/mceachen/closure_tree/pull/92).
  Thanks, [Kir Shatrov](https://github.com/kirs)!

* Dropped support for Rails 3.0.

### 4.3.0

* Use [foreigner](https://github.com/matthuhiggins/foreigner) to prove that
  things are inserted and deleted without violating foreign key constraints

* Added Rails 4.1.0.rc2 as a Travis CI build target

### 4.2.9

* Support for Heroku's cray assets:precompile hack for Rails 4.
  Addresses [issue 78](https://github.com/mceachen/closure_tree/issues/78).
  Thanks for the assist, [Alex Bowman](https://github.com/axlekb).

### 4.2.8

* More massaging for Rails 4 and ```attr_accessible``` support

### 4.2.7

* ```self_and_ancestors``` and ```ancestry_hierarchy``` are reloaded
  when nodes are reparented. Addresses [issue 68](https://github.com/mceachen/closure_tree/issues/68).
  Thanks for the assist, [Ivan Stana](https://github.com/istana).

### 4.2.6

* Explicitly added MIT licensing to the gemspec.

### 4.2.5

* Fix for potential deadlock from ```delete_hierarchy_references``` not being called within an
  advisory lock. Thanks, [Armando Guereca](https://github.com/aguereca), for finding that!

* Sped up find_or_create_by_path to skip cycle detection validation.
  A node whose ancestry was 200-deep took 20 seconds to create (!!), and now takes < 1 second.

* Fixed issue with MySQL that prevented nodes > 60 levels deep from being created

### 4.2.4

* Support for ```root?```, ```child?```, and proper parent-child associations
  when both the parent and the child are not persisted. Addresses [issue 64](https://github.com/mceachen/closure_tree/issues/64).
  Thanks for the help, [Gabriel Mazetto](https://github.com/brodock)!

### 4.2.3

* Fixed ```attr_accessible?``` error introduced in 4.2.2 ([issue 66](https://github.com/mceachen/closure_tree/issues/66)).
* Switched to use new WithAdvisoryLock::DatabaseAdapterSupport (in v0.0.9) to add Postgis support

### 4.2.2

* Support attr_accessible and strong_attributes even if you're on Rails 4

### 4.2.1

* Deleting from NumericDeterministicOrdering doesn't create sort order gaps anymore.

### 4.2.0

* Added ```with_ancestor(*ancestors)```. Thanks for the idea, [Matt](https://github.com/mgornick)!
* Applied [Leonel Galan](https://github.com/leonelgalan)'s fix for Strong Attribute support
* ```find_or_create_by``` now uses passed-in attributes as both selection and creation criteria.
  Thanks for the help, [Judd Blair](https://github.com/juddblair)!
  **Please note that this changes prior behavior—test your code with this new version!**
* ```ct_advisory_lock``` was moved into the ```_ct``` support class, to reduce model method pollution
* Moved a bunch of code into more focused piles of module mixins

### 4.1.0

* Added support for Rails 4.0.0.rc1 and Ruby 2.0.0 (while maintaining backward compatibility with Rails 3, BOOYA)
* Added ```#to_dot_digraph```, suitable for Graphviz rendering

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
