#!/bin/sh -ex
export BUNDLE_GEMFILE RBENV_VERSION DB

for RBENV_VERSION in 2.1.2 2.0.0-p481 1.9.3-p545
do
  gem install bundler rake # < just to make sure
  rbenv rehash || true
  for BUNDLE_GEMFILE in ci/Gemfile.activerecord-4.1.x ci/Gemfile.activerecord-4.0.x ci/Gemfile.activerecord-3.2.x ci/Gemfile.activerecord-3.1.x
  do
    bundle update --quiet
    for DB in mysql postgresql sqlite
    do
      echo $DB $BUNDLE_GEMFILE $RBENV_VERSION
      WITH_ADVISORY_LOCK_PREFIX=$(date +%s) bundle exec rake all_spec_flavors
    done
  done
done
