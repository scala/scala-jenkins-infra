#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-workers
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#


ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = chef_vault_item("master", "scala-jenkins-keypair")['private_key']
  end
end

credentialsMap = {
  'jenkins'  => '954dd564-ce8c-43d1-bcc5-97abffc81c57'
}

privKey = chef_vault_item("master", "scala-jenkins-keypair")['private_key']

# TODO: different keypairs to sandbox different workers better, just in case?
credentialsMap.each do |userName, uniqId|
  jenkins_private_key_credentials userName.dup do # dup is workaround for jenkins cookbook doing a gsub! in convert_to_groovy
    id uniqId
    private_key privKey
  end
end


masterEnvLambda = node["master"]["env"]

search(:node, 'name:jenkins-worker*').each do |worker|
  worker["jenkinsHomes"].each do |jenkinsHome, workerConfig|
    workerEnvLambda = workerConfig["env"]

    jenkins_ssh_slave workerConfig["workerName"] do
      host        worker.ipaddress
      credentials credentialsMap[workerConfig["jenkinsUser"]]  # must use id (groovy script fails otherwise)

      # TODO: make retrying more robust
      ssh_retries  10  # how often to retry when the SSH connection is refused during initial connect
      ssh_wait_retries  60  # seconds between retries

      remote_fs   jenkinsHome.dup
      jvm_options workerConfig["jvm_options"]

      java_path   workerConfig["java_path"] # only used on windows

      labels      workerConfig["labels"]
      executors   workerConfig["executors"]

      usage_mode  workerConfig["usage_mode"]

      # The availability of the node is managed by Jenkins,
      # the ec2-start-stop plugin will take the corresponding ec2 node [on|off]-line.
      availability    'demand'
      in_demand_delay workerConfig["in_demand_delay"]
      idle_delay      workerConfig["idle_delay"]

      # puts "Env for #{worker.name}:"
      # puts "masterEnvLambda: #{masterEnvLambda}"
      # puts "workerEnvLambda: #{workerEnvLambda}"
      masterEnv = (eval masterEnvLambda).call(worker)
      # puts "masterEnv: #{masterEnv}"
      workerEnv = (eval workerEnvLambda).call(worker)
      # puts "workerEnv: #{workerEnv}"

      environment(masterEnv.merge(workerEnv))

      action [:create] # we don't need to :connect, :online since the ec2 start/stop plugin will do that. Also, if connect fails, it may be that chef-client hasn't yet run on the client to initialize jenkins home with .ssh/authorized_keys
    end
  end
end
