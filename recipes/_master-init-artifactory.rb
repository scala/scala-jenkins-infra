
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-init-artifactory
#
# Copyright 2015, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# Socket Timeout: 30000
# Assumed Offline Limit: 0
# Missed Retrieval Cache Period: 0

include_recipe 'artifactory::default'
