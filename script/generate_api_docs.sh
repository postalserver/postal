#!/bin/bash

set -e

if [ ! -d /tmp/postal-api/.git ];
then
  git clone git@github.com:atech/postal-api /tmp/postal-api
else
  git -C /tmp/postal-api reset --hard HEAD
  git -C /tmp/postal-api pull origin master
fi

rm -Rf /tmp/postal-api/*

bundle exec moonrope api /tmp/postal-api

cd /tmp/postal-api

git add .
git commit -m "update docs"
git push origin master
