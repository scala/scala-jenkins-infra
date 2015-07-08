#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-debian
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "apt" # do apt-get update

include_recipe "scala-jenkins-infra::_java_packages"

# NOTE: MUST BE LAST -- it selects the chef-configured jdk (the above packages install openjdk 7 & 8, but we want something else)
include_recipe "java"
