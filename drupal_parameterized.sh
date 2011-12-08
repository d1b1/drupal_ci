#!/bin/bash

#set -x

env > "/var/aegir/jenkins/job_info/$JOB_NAME.log"

#TODO Add in argument validation
# The following are variables defined by the Jenkins Job. You
# can override them locally to get this script running. By adding
# parameterized variables and defaults, you give job owners more 
# options for configuration.
#
# $DRUPAL_PATH - Path to the drupal install
# $SITE_URL      - base domain for the test drupal site. No HTTP:// needed.
# $DRUSH_PATH    - Path to the drupal install directory. Default: /var/aegir/drush

PHP=`which php`
MODULES_DIR=$DRUPAL_PATH/sites/all/modules
SITE="http://$SITE_URL/"
DRUSH="$DRUSH_PATH/drush.php -n -r $DRUPAL_PATH -i $MODULES_DIR -l $SITE_URL"

echo ""
echo "--------------------------------------------------------"
echo "WorkSpace: $WORKSPACE"
echo "Platform Path: $PLATFORM_PATH"
echo "Site URL: $SITE_URL"
echo "Drush Path: $DRUSH_PATH"
echo "SimpleTest Class: $SIMPLETEST"
echo "Current Drush Command:"
echo $DRUSH
echo "--------------------------------------------------------"

# Output the Drush Information / UnComment to debug issues.
# echo `$PHP $DRUSH status`

EXITVAL=0

# Remove the .git so we do not have to kill it later while in link
echo "Removing the .git folder from the workspace."
rm -Rf $WORKSPACE/.git

# Check our syntax using PHP Lint
echo ""
echo "Starting Phase 1: PHP Syntax tests..."
PHP_FILES=`/usr/bin/find $WORKSPACE -type f -exec grep -q '<?php' {} \; -print`
for f in $PHP_FILES; do
  echo "FILE: $f"
  $PHP -l "$f"
  if [ $? != 0 ]; then
    let "EXITVAL += 1"
    echo "$f failed PHP lint test. STOPPING Job!"
    exit $EXITVAL
  fi
done

echo "SYNTAX: Lint test complete."
echo ""

echo "Rsynced the $MODULE_NAM to the $MODULES_DIR/$MODULE_NAME to Dev Site Modules Path."
/usr/bin/rsync -a --delete --exclude='.git' $WORKSPACE/* $MODULES_DIR/$MODULE_NAME

# Run update.php
# THIS IS NOT WORKING RESEARCH: $DRUSH updatedb -q --yes

echo "----------------------------------------------------"
echo "Starting Coder on '$MODULE_NAME'"
echo ""

# Run coder
# --------------------------------------------------------------------------------------
# D6 - CODER_OUTPUT="$DRUSH coder $MODULE_NAME"
# D7 - CODER_OUTPUT="$DRUSH coder-review $MODULE_NAME"

CODER_OUTPUT=`$DRUSH coder-review $MODULE_NAME no-empty `
echo "$CODER_OUTPUT"
echo ""

if [ -n "`echo $CODER_OUTPUT | grep -E '[0-9]* normal warnings' `" ]; then
  echo "Coder module reported errors. STOPPING Job!"  
  echo ""
  echo "------------------------------------------------------------------"
  echo ""
  exit 1
else
  echo "CODER PASS: Drupal code standards met in all workspace files."
fi

echo ""
echo "------------------------------------------------------------------"
echo "SIMPLETEST: Starting test: $SIMPLETEST"

if [ -n "$SIMPLETEST" ]; then 
  SIMPLETEST_RESULT="`$DRUSH test-run $SIMPLETEST --uri=$SITE_URL --xml=/var/aegir/jenkins/jobs/stations/ 2>&1`" 
  echo $SIMPLETEST_RESULT | grep ", 0 fails," >/dev/null
  EXITVAL=$?
else
  echo "Skipped - No web/unit ClassName set in parameters"
  EXITVAL=0
fi

echo $SIMPLETEST_RESULT
exit $EXITVAL

