#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-windows
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# TODO: not idempotent (java and jenkins slave service conflict)

# needed for other stuff (install ruby etc)
include_recipe 'aws'
include_recipe 'windows'

# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"
include_recipe "git"
include_recipe "chef-sbt"

# ??? must come later or it won't find ruby.exe, which is installed by git?
include_recipe "wix"

# XXX for the jenkins recipe: ensure_update_center_present! bombs without it (https://github.com/opscode-cookbooks/jenkins/issues/305)
ruby_block 'Enable ruby ssl on windows' do
  block do
    ENV[SSL_CERT_FILE] = 'c:\opscode\chef\embedded\ssl\certs\cacert.pem'
  end
  action :nothing
end

chef_gem "chef-vault"
require "chef-vault"

# Set the private key on the Jenkins executor
ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
    ## TODO why don't our attributes take effect??
    jenkinsMaster = search(:node, 'tags:jenkins-master').first
    node.set['jenkins']['master']['endpoint'] = jenkinsMaster.jenkins.master.endpoint
    Chef::Log.warn("End point: #{jenkinsMaster.jenkins.master.endpoint}")
  end
end

# if you specify a user, must also specify a password!! by default, runs under the LocalSystem account (no password needed)
# this is the only type of slave that will work on windows (the jnlp one does not launch automatically)
jenkins_windows_slave 'windows' do
  labels    ['windows']
  group "Administrators"

  executors 2

  environment(node["worker"]["windows"]["env"])

  action [:create, :connect]
end
