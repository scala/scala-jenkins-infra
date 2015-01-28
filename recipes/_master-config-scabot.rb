#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-init-scabot
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "git"
include_recipe "chef-sbt"

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
  mode      '644'
  content   ChefVault::Item.load("master", "scabot-keypair")['public_key']
end

node.set['scabot']['github']['token']  = ChefVault::Item.load("master", "scabot")['github']['token']
node.set['scabot']['jenkins']['token'] = ChefVault::Item.load("master", "scabot")['jenkins']['token']

git_user scabotUser do
  home      scabotHome
  # owner     scabotUser
  full_name 'Scabot'
  email     'adriaan@typesafe.com'
end

# scabotCheckout must be an empty dir
git scabotCheckout do
  user       scabotUser
  repository "https://github.com/scala/scabot.git"
  revision   "master"
end

template "#{scabotHome}/scabot.conf" do
  source    'scabot.conf.erb'
  user      scabotUser
  sensitive true
end

bash 'build scabot' do
  cwd  scabotCheckout
  user scabotUser
  code "sbt update && sbt stage"
end

# Include runit to setup the service
include_recipe 'runit::default'

# Create runit service
runit_service 'scabot' # see templates/default/sv-scabot-run.erb

