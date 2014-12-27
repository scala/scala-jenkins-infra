#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-linux
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# TODO: rework attribute setting...
node.set['java']['jdk_version']    = '6'
node.set['java']['install_flavor'] = 'oracle' # partest's javap tests fail on openjdk...
node.set['java']['oracle']['accept_oracle_download_terms'] = true

# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"

include_recipe "git"
include_recipe "chef-sbt" # TODO: remove, redundant with sbt-extras, but the latter won't work on windows
include_recipe "sbt-extras"

%w{ant}.each do |pkg|
  package pkg
end
