#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-windows-agent
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# XXX for the jenkins recipe: ensure_update_center_present! bombs without it (https://github.com/opscode-cookbooks/jenkins/issues/305)
ruby_block 'Enable ruby ssl on windows' do
  block do
    ENV[SSL_CERT_FILE] = 'c:\opscode\chef\embedded\ssl\certs\cacert.pem'
  end
  action :nothing
end

chef_gem "chef-vault"
require "chef-vault"

jenkinsMaster = search(:node, 'name:jenkins-master').first

# Set the private key on the Jenkins executor
ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
    node.set['jenkins']['master']['endpoint'] = "http://#{jenkinsMaster.ipaddress}:#{jenkinsMaster.jenkins.master.port}"
    Chef::Log.warn("Master end point: #{jenkinsMaster.jenkins.master.endpoint} / computed: #{node['jenkins']['master']['endpoint']}")
  end
end

# if you specify a user, must also specify a password!! by default, runs under the LocalSystem account (no password needed)
# this is the only type of slave that will work on windows (the jnlp one does not launch automatically)
jenkins_windows_slave 'windows' do
  labels  ['windows']
  group   "Administrators"
  tunnel  "#{jenkinsMaster.ipaddress}:" # specify tunnel that stays inside the VPC, needed to avoid going through the reverse proxy

  executors 2

  environment(node["master"]["env"].merge(node["worker"]["env"])) # TODO: factor out (can't configure jenkins global properties, so emulate at node-level using chef)

  action [:create, :connect, :online] # TODO: are both connect and online needed?
end
