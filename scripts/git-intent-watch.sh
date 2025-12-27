#!/usr/bin/env bash
# Git Intent-to-Add Watcher
#
# Purpose: Continuously run `git add --intent-to-add .` every 3 seconds
# Dependencies: git
# Related: None
#
# This script:
# - Runs git add --intent-to-add in a loop
# - Sleeps 3 seconds between iterations
# - Handles SIGINT for clean exit

trap 'echo -e "\nStopped."; exit 0' INT

while true; do
  git add --intent-to-add .
  sleep 3
done
