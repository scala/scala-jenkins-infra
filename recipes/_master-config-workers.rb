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
  'jenkins'  => '954dd564-ce8c-43d1-bcc5-97abffc81c57'
}

privKey = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']

# TODO: different keypairs
credentialsMap.each do |userName, uniqId|
  jenkins_private_key_credentials userName.dup do # dup is workaround for jenkins cookbook doing a gsub! in convert_to_groovy
    id uniqId
    private_key privKey
  end
end


search(:node, 'name:jenkins-worker*').each do |worker|
  worker["jenkinsHomes"].each do |jenkinsHome, workerConfig|
    jenkins_ssh_slave workerConfig["workerName"] do
      host        worker.ipaddress
      credentials credentialsMap[workerConfig["jenkinsUser"]]  # must use id (groovy script fails otherwise)

      # TODO: make retrying more robust
      max_num_retries  10  # how often to retry when the SSH connection is refused during initial connect
      retry_wait_time  60 # seconds between retries

      remote_fs   jenkinsHome.dup
      jvm_options workerConfig["jvm_options"]

      labels      workerConfig["labels"]
      executors   workerConfig["executors"]

      usage_mode  workerConfig["usage_mode"]

      # The availability of the node is managed by Jenkins,
      # the ec2-start-stop plugin will take the corresponding ec2 node [on|off]-line.
      availability    'demand'
      in_demand_delay workerConfig["in_demand_delay"]
      idle_delay      workerConfig["idle_delay"]

      environment((eval node["master"]["env"]).call(node).merge((eval workerConfig["env"]).call(worker)))

      action [:create] # TODO: we don't need to :connect, :online since the ec2 start/stop plugin will do that -- right?? Also, if connect fails, it may be that chef-client hasn't yet run on the client to initialize jenkins home with .ssh/authorized_keys (since /home is mounted on ephemeral)
    end
  end
end
