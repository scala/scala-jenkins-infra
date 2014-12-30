#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-config
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'scala-jenkins-infra::_master-config-auth-github'
include_recipe 'scala-jenkins-infra::_master-config-workers'
include_recipe 'scala-jenkins-infra::_master-config-jobs'