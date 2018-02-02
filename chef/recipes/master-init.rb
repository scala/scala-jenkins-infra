#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-init
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'scala-jenkins-infra::_init-chef-client'

include_recipe "scala-jenkins-infra::_java_packages"

include_recipe "java"

include_recipe "scala-jenkins-infra::_jvm-select"


# EBS -- must come before jenkins init since it mounts /var/lib/jenkins
include_recipe "scala-jenkins-infra::_config-ebs"

include_recipe "scala-jenkins-infra::_master-init-jenkins"

include_recipe "scala-jenkins-infra::_master-init-artifactory"

