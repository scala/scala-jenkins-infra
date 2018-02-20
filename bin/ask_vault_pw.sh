#!/bin/bash

# from https://coderwall.com/p/cjiljw/use-macos-keychain-for-ansible-vault-passwords -- nice!
security find-generic-password -s "ansible vault" -w
