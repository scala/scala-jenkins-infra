#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-config
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# This can only be run *after* bootstrap due to vault dependency.
# Also, it needs to run on every reboot of the worker instance(s),
# since jenkins's home dir is mounted on ephemeral storage (see chef/userdata/ubuntu-publish-c3.xlarge)

require 'chef-vault'

include_recipe "scala-jenkins-infra::_config-ebs"

node["jenkinsHomes"].each do |jenkinsHome, workerConfig|
  case node["platform_family"]
  when "windows"
    # the regular resource approach does not work for me
    execute 'create jenkins user' do
      command "net user /ADD #{workerConfig["jenkinsUser"]}"
      not_if  "net user #{workerConfig["jenkinsUser"]}"
    end
  else
    user workerConfig["jenkinsUser"] do
      home jenkinsHome
    end
  end

  directory jenkinsHome do
    owner workerConfig["jenkinsUser"]
    mode 00755
    action :create
  end

  directory "#{jenkinsHome}/.ssh" do
    owner workerConfig["jenkinsUser"]
  end

  file "#{jenkinsHome}/.ssh/authorized_keys" do
    owner workerConfig["jenkinsUser"]
    mode  '644'
    content chef_vault_item("master", "scala-jenkins-keypair")['public_key'] + "\n#{workerConfig['authorized_keys']}" # TODO: distinct keypair for each jenkins user
  end

  git_user workerConfig["jenkinsUser"] do
    home        jenkinsHome
    full_name   'Scala Jenkins'
    email       'adriaan@typesafe.com'
  end
end


include_recipe "scala-jenkins-infra::_worker-config-#{node["platform_family"]}"
