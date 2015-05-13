#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-config
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# This recipe needs access to the vault, so can't be run on EC2 bootstrap (would be nice to fix)


# NGINX REVERSE PROXY setup, in concert with JenkinsLocationConfiguration created in master-init
include_recipe 'scala-jenkins-infra::_master-config-proxy'

# Jenkins base config
include_recipe 'scala-jenkins-infra::_master-config-jenkins'

# SCABOT
include_recipe 'scala-jenkins-infra::_master-config-scabot'

