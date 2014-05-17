#!/bin/sh -ex
export RBENV_VERSION DB

for RBENV_VERSION in 2.1.2 2.0.0-p481 1.9.3-p545
do
  gem install bundler rake # < just to make sure
  rbenv rehash || true
  appraisal install
    for DB in sqlite mysql postgresql
    do
      echo $DB $RBENV_VERSION
      WITH_ADVISORY_LOCK_PREFIX=$(date +%s) bundle exec appraisal rake all_spec_flavors
    done
done