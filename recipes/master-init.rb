#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-init
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'chef-client::service'

include_recipe "java"

include_recipe "scala-jenkins-infra::_master-init-jenkins"


case node["platform"]
when "amazon"
  # https://github.com/scala/scala-jenkins-infra/issues/26
  # workaround from https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1317811/comments/22 (until we can upgrade to kernel with fix -- >3.16.1)
  execute 'turn off scatter-gatter' do
    command "ethtool -K eth0 sg off"
  end
end
