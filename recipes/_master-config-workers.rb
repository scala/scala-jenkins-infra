#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-workers
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

require "chef-vault"

ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
  end
end

credentialsMap = {
  'jenkins-pub'  => '954dd564-ce8c-43d1-bcc5-97abffc81c54',
  'jenkins-priv' => '954dd564-ce8c-43d1-bcc5-97abffc81c55'
}

privKey = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']

# TODO: different keypairs
credentialsMap.each do |userName, uniqId|
  jenkins_private_key_credentials userName.dup do # dup is workaround for jenkins cookbook doing a gsub! in convert_to_groovy
    id uniqId
    private_key privKey
  end
end


search(:node, 'name:jenkins-worker* AND os:linux').each do |worker|
  worker["jenkinsHomes"].each do |jenkinsHome, workerConfig|
    jenkins_ssh_slave workerConfig["workerName"] do
      host        worker.ipaddress
      credentials credentialsMap[workerConfig["jenkinsUser"]]  # must use id (groovy script fails otherwise)
      remote_fs   jenkinsHome.dup

      labels      workerConfig["labels"]
      executors   workerConfig["executors"]

      environment(node["master"]["env"].merge(workerConfig["env"]))

      action [:create, :connect, :online]
    end
  end
end
