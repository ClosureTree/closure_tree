#!/bin/sh -ex
export BUNDLE_GEMFILE RMI DB

# On homebrew & mountain lion:
# CONFIGURE_OPTS=--without-tk rbenv install 1.8.7-p370
#
# for RMI in 1.8.7-p370 1.9.3-p429
# do
#   rbenv local $RMI
#   gem install bundler rake # < just to make sure
#   rbenv rehash || true
#
#   for BUNDLE_GEMFILE in ci/Gemfile.rails-3.0.x ci/Gemfile.rails-3.1.x
#   do
#     bundle update --quiet
#     for DB in sqlite mysql postgresql
#     do
#       echo $DB $BUNDLE_GEMFILE `ruby -v`
#       WITH_ADVISORY_LOCK_PREFIX=$(date +%s) bundle exec rake all_spec_flavors
#     done
#   done
# done

for RMI in 1.9.3-p429 2.0.0-p195
do
  rbenv local $RMI
  gem install bundler rake # < just to make sure
  rbenv rehash || true
  for BUNDLE_GEMFILE in ci/Gemfile.rails-4.0.x ci/Gemfile.rails-3.2.x
  do
    bundle update --quiet
    for DB in mysql postgresql sqlite
    do
      echo $DB $BUNDLE_GEMFILE `ruby -v`
      WITH_ADVISORY_LOCK_PREFIX=$(date +%s) bundle exec rake all_spec_flavors
    done
  done
done
