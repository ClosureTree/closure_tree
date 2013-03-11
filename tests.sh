#!/bin/sh -ex
export BUNDLE_GEMFILE RMI DB

for RMI in 1.8.7-p370 1.9.3-p327
do
  rbenv local $RMI
  gem install bundler rake # < just to make sure
  rbenv rehash || true

  for BUNDLE_GEMFILE in ci/Gemfile.rails-3.0.x ci/Gemfile.rails-3.1.x ci/Gemfile.rails-3.2.x
  do
    bundle update --quiet
    for DB in sqlite mysql postgresql
    do
      echo $DB $BUNDLE_GEMFILE `ruby -v`
      bundle exec rake specs_with_db_ixes
    done
  done
done

rbenv local 1.9.3-p327
export BUNDLE_GEMFILE=ci/Gemfile.rails-4.0.x
bundle update --quiet
for DB in sqlite mysql postgresql
do
  echo $DB $BUNDLE_GEMFILE `ruby -v`
  bundle exec rake specs_with_db_ixes
done
