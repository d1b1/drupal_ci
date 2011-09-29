#!/bin/bash

#set -x

env > "/var/aegir/jenkins/job_info/$JOB_NAME.log"

PLATFORM_PATH=/var/aegir/platforms/testing/pressflow-6.20.97-DEVELOPMENT
SITE_URL="jenkins-development.pws.local"
echo "Platform: $PLATFORM_PATH"
echo "Site URL: $SITE_URL"

PHP=`which php`
DRUSH_PATH=/var/aegir/drush
DRUPAL_PATH=$PLATFORM_PATH
MODULES_DIR=$PLATFORM_PATH/sites/all/modules
SITE="http://$SITE_URL/"

#DRUSH="$PHP $DRUSH_PATH/drush.php -n -r $DRUPAL_PATH -i $DRUPAL_PATH -l $SITE_URL"
DRUSH="$DRUSH_PATH/drush.php -n -r $DRUPAL_PATH -i $MODULES_DIR -l $SITE_URL"
#DRUSH="$DRUSH_PATH/drush.php -n -r $DRUPAL_PATH  -l $SITE_URL"

echo "Current Drush Command:"
echo $DRUSH
echo ""

echo `$PHP $DRUSH status`

EXITVAL=0

echo "$WORKSPACE"
echo ""

##rm -Rf $WORKSPACE/.git

# Check our syntax
PHP_FILES=`/usr/bin/find $WORKSPACE -type f -exec grep -q '<?php' {} \; -print`
for f in $PHP_FILES; do
  echo "FILE: $f"
  $PHP -l "$f"
  if [ $? != 0 ]; then
    let "EXITVAL += 1"
    echo "$f failed PHP lint test, not syncing to ngdemo website."
    exit $EXITVAL
  fi
done

echo "SYNTAX: Lint test complete."
echo ""

echo "Rsynced the $MODULE_NAM to the $MODULES_DIR/$MODULE_NAME to test."
/usr/bin/rsync -a --delete --exclude='.git' $WORKSPACE/* $MODULES_DIR/van/$MODULE_NAME

#Run update.php
# THIS IS NOT WORKING RESEARCH: $DRUSH updatedb -q --yes

echo "Starting Coder on $MODULE_NAME"

#Run coder
CODER_OUTPUT=`$DRUSH coder $MODULE_NAME`
echo "$CODER_OUTPUT"
if [ -n "`echo $CODER_OUTPUT | grep -e '[0-9]* [a-z]* warnings'`" ]; then
  echo "**CODER FAIL** - Coder module reported errors."
  let "EXITVAL += 1"
else
  echo "CODER PASS: Drupal code standards met in all workspace files."
fi

echo "Coder module tests complete."
echo ""

echo "Stopping without running the simpletests"
exit $EXITVAL

echo "SIMPLETEST: Starting the Drupal Unit Test Suite"

echo "PHP: $PHP"

CLASS_NAME=$(echo "${JOB_NAME}_unit")
UNITTEST_OUTPUT=`$PHP $DRUPAL_PATH/scripts/run-tests.sh \
       --url "$SITE_URL" \
       --verbose \
       --xml $DRUPAL_PATH/scripts/tests/$JOB_NAME \
       --class $CLASS_NAME`
       --php $PHP

echo ""
echo "Starting the Second"

CLASS_NAME=$(echo "${JOB_NAME}_functional")
FUNCTIONALTEST_OUTPUT=`$PHP $DRUPAL_PATH/scripts/run-tests.sh \
   --url "$SITE_URL" \
   --verbose \
   --xml $DRUPAL_PATH/scripts/tests/$JOB_NAME \
   --class $CLASS_NAME`
   --php $PHP

echo "$UNITTEST_OUTPUT"
echo "$FUNCTIONALTEST_OUTPUT"

exit $EXITVAL
