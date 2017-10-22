#!/bin/sh
if ! which drafter > /dev/null; then echo "install drafter: brew install drafter"; exit 1; fi
if ! which SwiftBeaker > /dev/null; then echo "install SwiftBeaker: https://github.com/banjun/SwiftBeaker/releases"; exit 1; fi
drafter -f json Mastodon.md > Mastodon.md.ast.json && SwiftBeaker Mastodon.md.ast.json > Mastodon.swift
