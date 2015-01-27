#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-config
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

require "chef-vault"

ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
  end
end


# nginx reverse proxy setup, in concert with JenkinsLocationConfiguration created in master-init
include_recipe 'scala-jenkins-infra::_master-config-proxy'

# set up chef user with public key from our master/scala-jenkins-keypair vault
template "#{node['jenkins']['master']['home']}/users/chef/config.xml" do
  source 'chef-user-config.erb'
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']

  variables({
    :pubkey => ChefVault::Item.load("master", "scala-jenkins-keypair")['public_key']
  })
end

%w(notification ssh-credentials build-name-setter cygpath job-dsl build-flow-plugin rebuild greenballs build-timeout copyartifact email-ext slack throttle-concurrents dashboard-view parameterized-trigger).each do |plugin|
  plugin, version = plugin.split('=') # in case we decide to pin versions later
  jenkins_plugin plugin
end

jenkins_plugin "ec2-start-stop" do
  source   node['master']['ec2-start-stop']['url']
  # doesn't support checksum
end

# restart jenkins (TODO: wait for it to come back up, so we can continue automatically with next recipes; until then, manually)
# Theory for observed failure: github-oauth plugin needs restart
# next steps: add scala-jenkins-infra::master-auth-github, and scala-jenkins-infra::master-workers (once they are up) to run_list
jenkins_plugin "github-oauth" do
  # To be sure, do safe restart (see subscribes below), since we're running chef every thirty minutes
end

jenkins_command 'safe-restart' do
  action :nothing
  subscribes :execute, 'jenkins_plugin[github-oauth]', :delayed
end

include_recipe 'scala-jenkins-infra::_master-config-auth-github'

include_recipe 'scala-jenkins-infra::_master-config-jobs'

include_recipe 'scala-jenkins-infra::_master-config-workers'

include_recipe 'scala-jenkins-infra::_master-config-scabot'

