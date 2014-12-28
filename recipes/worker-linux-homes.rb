#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-linux-homes
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# This can only be run *after* bootstrap due to vault dependency
# thus, factored out of worker-linux.
# Also, it needs to run on every reboot of the worker instance(s),
# since jenkins's home dir is mounted on ephemeral storage (see chef/userdata/ubuntu-publish-c3.xlarge)

chef_gem "chef-vault"
require "chef-vault"

# TODO: factor out duplication
node.set["jenkinsHomes"]["/home/jenkins-priv"]["env"]["sbtLauncher"] = File.join(node['sbt']['launcher_path'], "sbt-launch.jar") # from chef-sbt cookbook
node.set["jenkinsHomes"]["/home/jenkins-priv"]["env"]["sbtCmd"]      = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
node.set["jenkinsHomes"]["/home/jenkins-priv"]["env"]["JAVA_HOME"]   = node['java']['java_home'] # we get the jre if we don't do this
node.set["jenkinsHomes"]["/home/jenkins-priv"]["executors"]          = 2
node.set["jenkinsHomes"]["/home/jenkins-priv"]["workerName"]         = "builder-ubuntu-priv"
node.set["jenkinsHomes"]["/home/jenkins-priv"]["labels"]             = ["linux", "publish"]
node.set["jenkinsHomes"]["/home/jenkins-priv"]["jenkinsUser"]        = "jenkins-priv"

node.set["jenkinsHomes"]["/home/jenkins-pub"]["env"]["sbtLauncher"] = File.join(node['sbt']['launcher_path'], "sbt-launch.jar") # from chef-sbt cookbook
node.set["jenkinsHomes"]["/home/jenkins-pub"]["env"]["sbtCmd"]      = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
node.set["jenkinsHomes"]["/home/jenkins-pub"]["env"]["JAVA_HOME"]   = node['java']['java_home'] # we get the jre if we don't do this
node.set["jenkinsHomes"]["/home/jenkins-pub"]["executors"]          = 4
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
