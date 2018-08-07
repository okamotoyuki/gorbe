#!/bin/bash

# Compile ruby script to go module
cd ..
./gorbec ./sandbox/hello.rb > ./sandbox/hello/module.go
