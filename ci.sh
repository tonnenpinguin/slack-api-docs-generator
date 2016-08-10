#! /bin/sh

D_DIR=$(mktemp -d)
echo "$D_DIR"
rm -rf "$D_DIR"
git clone git@github.com:aki017/slack-api-docs "$D_DIR" -b master
bundle exec ruby main.rb "$D_DIR"
cd "$D_DIR" && git add . && git commit -m "auto commited `date`" && git push origin master
rm -rf "$D_DIR"
