#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-init
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe "scala-jenkins-infra::_config-ebs"

include_recipe 'scala-jenkins-infra::_init-chef-client'

include_recipe "scala-jenkins-infra::_worker-init-#{node["platform_family"]}"

include_recipe "scala-jenkins-infra::_jvm-select"

