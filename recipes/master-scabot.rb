#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-scabot
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "git"
include_recipe "sbt-extras"

scabotHome     = "/home/scabot"
scabotCheckout = "/home/scabot/scabot"
scabotUser     = "scabot"

user scabotUser

directory scabotHome do
  owner     scabotUser
  mode      00755
  action    :create
end

directory scabotCheckout do
  owner     scabotUser
  mode      00755
  action    :create
end

directory "#{scabotHome}/logs" do
  owner     scabotUser
  mode      00755
  action    :create
end

directory "#{scabotHome}/.ssh" do
  owner     scabotUser
end


file "#{scabotHome}/.ssh/authorized_keys" do
  owner     scabotUser
  mode      '600'
  content   chef_vault_item("master", "scabot-keypair")['public_key']
end

git_user scabotUser do
  home      scabotHome
  # owner     scabotUser
  full_name 'Scabot'
  email     'adriaan@lightbend.com'
end

# scabotCheckout must be an empty dir
git scabotCheckout do
  user       scabotUser
  repository "https://github.com/scala/scabot.git"
  revision   "master"
end

bash 'git config' do
  cwd  scabotCheckout
  user scabotUser
  code "git config receive.denyCurrentBranch ignore"
end

cookbook_file "scabot-post-receive" do
  mode '755'
  path "#{scabotHome}/scabot/.git/hooks/post-receive"
end

template "#{scabotHome}/scabot.conf" do
  source    'scabot.conf.erb'
  user      scabotUser
  sensitive true

  variables({
    :scabotVault => chef_vault_item("master", "scabot")
  })

end

template "#{scabotHome}/production.conf" do
  source    'scabot-production.conf.erb'
  user      scabotUser
  sensitive true

  variables({
    :scabotVault => chef_vault_item("master", "scabot")
  })

end

bash 'build scabot' do
  cwd  scabotCheckout
  user scabotUser
  code "scripts/stage"
end

# Include runit to setup the service
include_recipe 'runit::default'

# Create runit service
runit_service 'scabot' # see templates/default/sv-scabot-run.erb

