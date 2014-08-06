#!/bin/sh -ex

for RMI in 2.1.2 jruby-1.6.13
do
  rbenv local $RMI
  for db in postgresql mysql sqlite
  do
    appraisal bundle update
    DB=$db WITH_ADVISORY_LOCK_PREFIX=$(date +%s) appraisal rake all_spec_flavors
  done
done
