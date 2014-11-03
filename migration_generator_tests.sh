#!/bin/sh -ex

# These tests don't run properly on Travis, so this needs to pass before
# releasing new versions of the gem:
for RUBY in 2.1.4 1.9.3-p545 jruby-1.6.13
do
  rbenv local $RUBY
  appraisal bundle update
  export DB
  for DB in mysql sqlite postgresql ; do
    WITH_ADVISORY_LOCK_PREFIX=$(date +%s) appraisal rspec spec/generator_spec.rb
  done
done
