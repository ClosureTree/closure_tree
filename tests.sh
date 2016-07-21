#!/bin/sh -ex

for RMI in 2.3.1 #jruby-1.6.13 :P
do
  rbenv local $RMI
  appraisal bundle install
  for DB in mysql sqlite postgresql
  do
    appraisal rake spec:all WITH_ADVISORY_LOCK_PREFIX=$(date +%s) DB=$DB
  done
done
