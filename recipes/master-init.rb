#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-init
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'chef-client::service'

chef_gem "chef-vault"

# The jenkins cookbook comes with a very simple java installer. If you need more
#  complex java installs you are on your own.
#  https://github.com/opscode-cookbooks/jenkins#java
include_recipe 'jenkins::java'
include_recipe 'jenkins::master'

# recursive doesn't set owner correctly??
directory "#{node['jenkins']['master']['home']}/users" do
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
end

directory "#{node['jenkins']['master']['home']}/users/chef/" do
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
end


# NOTE: the following attributes must be configured thusly (jenkins-cli comms will stay in the VPC)
#   see also on the workers: `node.set['jenkins']['master']['endpoint'] = "http://#{jenkinsMaster.ipaddress}:#{jenkinsMaster.jenkins.master.port}"`
# under jenkins.master
    # host: localhost
    # listen_address: 0.0.0.0
    # port: 8080
    # endpoint: http://localhost:8080
# keep endpoint at localhost (stay in VPC), must set this for reverse proxy to work
template "#{node['jenkins']['master']['home']}/jenkins.model.JenkinsLocationConfiguration.xml" do
  source 'jenkins.model.JenkinsLocationConfiguration.xml.erb'
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  variables({
    :adminAddress => node['master']['adminAddress'],
    :jenkinsUrl   => node['master']['jenkinsUrl']
  })
end

# https://github.com/scala/scala-jenkins-infra/issues/26
# workaround from https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1317811/comments/22 (until we can upgrade to kernel with fix -- >3.16.1)
execute 'turn off scatter-gatter' do
  command "ethtool -K eth0 sg off"
end
