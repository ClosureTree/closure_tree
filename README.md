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
"_hierarchy".

