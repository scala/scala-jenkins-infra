#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _config-adminKeys
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

adminUser = platform_family?('debian') ? 'ubuntu' : 'ec2-user'

directory "/home/#{adminUser}/.ssh" do
  owner adminUser
end

file "/home/#{adminUser}/.ssh/authorized_keys" do
  owner adminUser
  mode  '600'
  content node['authorized_keys']['admin']
end
