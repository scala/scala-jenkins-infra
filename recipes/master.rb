#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
chef_gem "chef-vault"
require "chef-vault"

# NOTE: the following attributes must be configured thusly (jenkins-cli comms will stay in the VPC)
#   see also on the workers: `node.set['jenkins']['master']['endpoint'] = "http://#{jenkinsMaster.ipaddress}:#{jenkinsMaster.jenkins.master.port}"`
# under jenkins.master
    # host: localhost
    # listen_address: 0.0.0.0
    # port: 8080
    # endpoint: http://localhost:8080


# The jenkins cookbook comes with a very simple java installer. If you need more
#  complex java installs you are on your own.
#  https://github.com/opscode-cookbooks/jenkins#java
include_recipe 'jenkins::java'
include_recipe 'jenkins::master'

directory "#{node['jenkins']['master']['home']}/users/chef/" do
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  recursive true
end

# set up chef user with public key from our master/scala-jenkins-keypair vault
template "#{node['jenkins']['master']['home']}/users/chef/config.xml" do
  source 'chef-user-config.erb'
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']

  variables({
    :pubkey => ChefVault::Item.load("master", "scala-jenkins-keypair")['public_key']
  })
end

# see NOTE above about keeping endpoint at localhost (stay in VPC), but must set this for reverse proxy to work
template "#{node['jenkins']['master']['home']}/jenkins.model.JenkinsLocationConfiguration.xml" do
  source 'jenkins.model.JenkinsLocationConfiguration.xml.erb'
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  variables({
    :adminAddress => node['master']['adminAddress'],
    :jenkinsUrl   => node['master']['jenkinsUrl']
  })
end

ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
  end
end

%w(ssh-credentials job-dsl build-flow-plugin rebuild greenballs build-timeout copyartifact email-ext slack throttle-concurrents dashboard-view parameterized-trigger).each do |plugin|
  plugin, version = plugin.split('=') # in case we decide to pin versions later
  jenkins_plugin plugin
end

# restart jenkins (TODO: wait for it to come back up, so we can continue automatically with next recipes; until then, manually)
# Theory for observed failure: github-oauth plugin needs restart
# next steps: add scala-jenkins-infra::master-auth-github, and scala-jenkins-infra::master-workers (once they are up) to run_list
jenkins_plugin "github-oauth" do
  notifies :restart, 'runit_service[jenkins]', :immediately
end
