#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-linux
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

node.set["worker"]["env"]["sbtLauncher"] = File.join(node['sbt']['launcher_path'], "sbt-launcher.jar") # from chef-sbt cookbook
node.set["worker"]["env"]["sbtCmd"]      = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras


# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"
include_recipe "git"
include_recipe "chef-sbt" # TODO: remove, redundant with sbt-extras, but the latter won't work on windows
include_recipe "sbt-extras"

%w{ant}.each do |pkg|
  package pkg
end

user "jenkins" do
  home "/home/jenkins"
end

directory "/home/jenkins" do
  owner "jenkins"
  group "jenkins"
  mode 00755
  action :create
end

directory "/home/jenkins/.ssh" do
  owner "jenkins"
end

git_user 'jenkins' do
  full_name   'Scala Jenkins'
  email       'adriaan@typesafe.com'
end

chef_gem "chef-vault"
require "chef-vault"

file "/home/jenkins/.ssh/authorized_keys" do
  owner 'jenkins'
  mode '644'
  content ChefVault::Item.load("master", "scala-jenkins-keypair")['public_key'] #.join("\n")
end

# Set the private key on the Jenkins executor
ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
    ## TODO why don't our attributes take effect?? tried override[..] in default.rb
    jenkinsMaster = search(:node, 'name:jenkins-master').first
    node.set['jenkins']['master']['endpoint'] = "http://#{jenkinsMaster.ipaddress}:#{jenkinsMaster.jenkins.master.port}"
    Chef::Log.warn("Master end point: #{jenkinsMaster.jenkins.master.endpoint} / computed: #{node['jenkins']['master']['endpoint']}")
  end
end

