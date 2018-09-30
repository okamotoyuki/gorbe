#!/bin/bash

# Compile ruby script to go module
cd ..
mkdir -p ./playground/hello
./gorbec ./playground/hello.rb > ./playground/hello/module.go
