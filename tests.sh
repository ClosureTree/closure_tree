#!/bin/sh -ex

for RMI in 2.1.4 #jruby-1.6.13 :P
do
  rbenv local $RMI
  for DB in postgresql mysql sqlite
  do
    appraisal rake spec:generators WITH_ADVISORY_LOCK_PREFIX=$(date +%s) DB=$DB
  done
done
