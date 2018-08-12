#!/usr/bin/env bash

# Execute only one unit test by the test ID

TEST_ID=$1
TEST_SAMPLE_DIR=`cd $(dirname $0); pwd`/../test/sample

if [[ ! $TEST_ID =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo 'Test ID should be /^[0-9]+\.[0-9]+$/ format!'
  exit 1
fi

TEST_CATEGORY_ID=`echo $TEST_ID | cut -d. -f 1`
TEST_ITEM_ID=`echo $TEST_ID | cut -d. -f 2`

TEST_CATEGORY_DIR=`find $TEST_SAMPLE_DIR -name $TEST_CATEGORY_ID\_* -type d -maxdepth 1`
TEST_ITEM_PATH=`find $TEST_SAMPLE_DIR -name $TEST_ID\_* -type f -maxdepth 2`

TEST_CATEGORY=`echo $TEST_CATEGORY_DIR | awk -F/ '{print $NF}' | cut -d_ -f 2`
TEST_ITEM=`echo $TEST_ITEM_PATH | awk -F/ '{print $NF}' | awk -F'[.|_]' '{print $(NF-1)}'`

TEST_METHOD='test_core_'$TEST_CATEGORY_ID'_'$TEST_CATEGORY'_'$TEST_ITEM_ID'_'$TEST_ITEM

rake test TESTOPTS="--name=$TEST_METHOD -v"
