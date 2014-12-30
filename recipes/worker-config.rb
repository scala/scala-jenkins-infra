#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-config
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "scala-jenkins-infra::_worker-config-#{node["platform_family"]}"
