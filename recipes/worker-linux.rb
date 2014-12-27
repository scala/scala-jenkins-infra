#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-linux
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
chef_gem "chef-vault"
require "chef-vault"


# TODO: rework attribute setting...
node.set['java']['jdk_version']    = '6'
node.set['java']['install_flavor'] = 'oracle' # partest's javap tests fail on openjdk...
node.set['java']['oracle']['accept_oracle_download_terms'] = true

# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"

include_recipe "git"
include_recipe "chef-sbt" # TODO: remove, redundant with sbt-extras, but the latter won't work on windows
include_recipe "sbt-extras"

%w{ant}.each do |pkg|
  package pkg
end

# TODO: factor out duplication
node.set["jenkinsHomes"]["/home/jenkins-priv"]["env"]["sbtLauncher"] = File.join(node['sbt']['launcher_path'], "sbt-launch.jar") # from chef-sbt cookbook
node.set["jenkinsHomes"]["/home/jenkins-priv"]["env"]["sbtCmd"]      = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
node.set["jenkinsHomes"]["/home/jenkins-priv"]["env"]["JAVA_HOME"]   = node['java']['java_home'] # we get the jre if we don't do this
node.set["jenkinsHomes"]["/home/jenkins-priv"]["executors"]          = 2
node.set["jenkinsHomes"]["/home/jenkins-priv"]["workerName"]         = "builder-ubuntu-priv"
node.set["jenkinsHomes"]["/home/jenkins-priv"]["labels"]             = ["linux"]
node.set["jenkinsHomes"]["/home/jenkins-priv"]["jenkinsUser"]        = "jenkins-priv"

node.set["jenkinsHomes"]["/home/jenkins-pub"]["env"]["sbtLauncher"] = File.join(node['sbt']['launcher_path'], "sbt-launch.jar") # from chef-sbt cookbook
node.set["jenkinsHomes"]["/home/jenkins-pub"]["env"]["sbtCmd"]      = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
node.set["jenkinsHomes"]["/home/jenkins-pub"]["env"]["JAVA_HOME"]   = node['java']['java_home'] # we get the jre if we don't do this
node.set["jenkinsHomes"]["/home/jenkins-pub"]["executors"]          = 2
node.set["jenkinsHomes"]["/home/jenkins-pub"]["workerName"]         = "builder-ubuntu-pub"
node.set["jenkinsHomes"]["/home/jenkins-pub"]["labels"]             = ["linux"]
node.set["jenkinsHomes"]["/home/jenkins-pub"]["jenkinsUser"]        = "jenkins-pub"

node["jenkinsHomes"].each do |jenkinsHome, workerConfig|
  user workerConfig["jenkinsUser"] do
    home jenkinsHome
  end

  directory jenkinsHome do
    owner workerConfig["jenkinsUser"]
    group workerConfig["jenkinsUser"]
    mode 00755
    action :create
  end

  directory "#{jenkinsHome}/.ssh" do
    owner workerConfig["jenkinsUser"]
  end

  file "#{jenkinsHome}/.ssh/authorized_keys" do
    owner workerConfig["jenkinsUser"]
    mode  '644'
    content ChefVault::Item.load("master", "scala-jenkins-keypair")['public_key'] # TODO: distinct keypair for each jenkins user
  end

  git_user workerConfig["jenkinsUser"] do
    full_name   'Scala Jenkins'
    email       'adriaan@typesafe.com'
  end
end
