#!/bin/sh -ex

appraisal install

for db in sqlite mysql postgresql
do
  DB=$db WITH_ADVISORY_LOCK_PREFIX=$(date +%s) appraisal rake all_spec_flavors
done
