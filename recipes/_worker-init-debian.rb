#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-debian
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"

include_recipe "sbt-extras"

%w{ant}.each do |pkg|
  package pkg
end
