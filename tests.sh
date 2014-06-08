#!/bin/sh -ex

appraisal install

for RMI in 1.9.3-p429 2.1.2
do
  rbenv local $RMI
  for db in postgresql mysql sqlite
  do
    bundle install --quiet
    DB=$db WITH_ADVISORY_LOCK_PREFIX=$(date +%s) appraisal rake all_spec_flavors
  done
done
