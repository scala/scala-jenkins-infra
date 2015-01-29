#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-debian
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "apt" # do apt-get update

%w{ant ant-contrib ant-optional maven}.each do |pkg|
  package pkg
end

# NOTE: MUST BE LAST -- it selects the chef-configured jdk (the above packages install openjdk 7, but we want something else)
include_recipe "java"
