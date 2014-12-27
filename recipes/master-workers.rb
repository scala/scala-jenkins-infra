#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-workers
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

chef_gem "chef-vault"
require "chef-vault"

ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
  end
end

jenkins_private_key_credentials 'jenkins' do # username == name of resource
  id '954dd564-ce8c-43d1-bcc5-97abffc81c54'
  private_key ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
end

search(:node, 'name:jenkins-worker* AND os:linux').each do |worker|
  worker["jenkinsHomes"].each do |jenkinsHome, workerConfig|
    jenkins_ssh_slave workerConfig["workerName"] do
      host        worker.ipaddress
      credentials '954dd564-ce8c-43d1-bcc5-97abffc81c54' # must use id (groovy script fails otherwise)

      labels      workerConfig["labels"]

      executors   workerConfig["executors"]

      environment(node["master"]["env"].merge(workerConfig["env"]))

      action [:create, :connect]
    end
  end
end