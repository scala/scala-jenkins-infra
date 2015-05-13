#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-jenkins
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# Config base Jenkins setup and restart
ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = chef_vault_item("master", "scala-jenkins-keypair")['private_key']
  end
end

## set up chef user with public key from our master/scala-jenkins-keypair vault
template "#{node['jenkins']['master']['home']}/users/chef/config.xml" do
  source 'chef-user-config.erb'
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']

  variables({
    :pubkey => chef_vault_item("master", "scala-jenkins-keypair")['public_key']
  })
end

%w(notification ssh-credentials groovy cygpath job-dsl build-flow-plugin rebuild greenballs build-timeout copyartifact email-ext slack throttle-concurrents dashboard-view parameterized-trigger).each do |plugin|
  plugin, version = plugin.split('=') # in case we decide to pin versions later
  jenkins_plugin plugin
end

jenkins_plugin "ec2-start-stop" do
  source   node['master']['ec2-start-stop']['url']
  # doesn't support checksum
end

jenkins_plugin "github-oauth" do
  notifies :restart, 'runit_service[jenkins]', :immediately
end