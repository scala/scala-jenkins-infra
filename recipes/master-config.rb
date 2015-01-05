#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-config
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

require "chef-vault"

# set up chef user with public key from our master/scala-jenkins-keypair vault
template "#{node['jenkins']['master']['home']}/users/chef/config.xml" do
  source 'chef-user-config.erb'
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']

  variables({
    :pubkey => ChefVault::Item.load("master", "scala-jenkins-keypair")['public_key']
  })
end

ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
  end
end

include_recipe 'scala-jenkins-infra::_master-config-auth-github'

include_recipe 'scala-jenkins-infra::_master-config-workers'

include_recipe 'scala-jenkins-infra::_master-config-jobs'