#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-config-rhel
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# This can only be run *after* bootstrap due to vault dependency
# thus, factored out of worker-linux.
# Also, it needs to run on every reboot of the worker instance(s),
# since jenkins's home dir is mounted on ephemeral storage (see chef/userdata/ubuntu-publish-c3.xlarge)

require 'chef-vault'

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
