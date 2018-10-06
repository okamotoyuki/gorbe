#!/usr/bin/env bash

# Execute unit tests which only match the given keyword
rake test TESTOPTS="--name=/$1/ -v"
