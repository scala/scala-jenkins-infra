#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#


# The jenkins cookbook comes with a very simple java installer. If you need more
#  complex java installs you are on your own.
#  https://github.com/opscode-cookbooks/jenkins#java
include_recipe 'jenkins::java'

# There is a bug in the latest Jenkins that breaks the api/ssh key auth.
# Also you can not pin packages using apt/yum with Jenkins repo
# So we opt for the war install and pin to 1.555
# * https://issues.jenkins-ci.org/browse/JENKINS-22346
# * https://github.com/opscode-cookbooks/jenkins/issues/170
node.set['jenkins']['master']['install_method'] = 'war'
node.set['jenkins']['master']['version']  = '1.555'
node.set['jenkins']['master']['source']   = "#{node['jenkins']['master']['mirror']}/war/#{node['jenkins']['master']['version']}/jenkins.war"
node.set['jenkins']['master']['checksum'] = '31f5c2a3f7e843f7051253d640f07f7c24df5e9ec271de21e92dac0d7ca19431'

include_recipe 'jenkins::master'

%w(github-oauth job-dsl greenballs build-timeout copyartifact email-ext slack throttle-concurrents dashboard-view parameterized-trigger).each do |plugin|
  plugin, version = plugin.split('=') # in case we decide to pin versions later
  jenkins_plugin plugin
end