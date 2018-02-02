#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-jenkins
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# run after master-config + jenkins restart

# ON FIRST PROVISION, MAKE SURE JENKINS HAS BEEN RESTARTED
# Plugins don't take effect until that, so `_master-config-auth-github` would fail
include_recipe 'scala-jenkins-infra::_master-jenkins-auth-github'
include_recipe 'scala-jenkins-infra::_master-jenkins-jobs'
include_recipe 'scala-jenkins-infra::_master-jenkins-workers'

