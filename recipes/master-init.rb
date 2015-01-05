#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-init
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'chef-client::service'

chef_gem "chef-vault"

# The jenkins cookbook comes with a very simple java installer. If you need more
#  complex java installs you are on your own.
#  https://github.com/opscode-cookbooks/jenkins#java
include_recipe 'jenkins::java'
include_recipe 'jenkins::master'

directory "#{node['jenkins']['master']['home']}/users/chef/" do
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  recursive true
end


# NOTE: the following attributes must be configured thusly (jenkins-cli comms will stay in the VPC)
#   see also on the workers: `node.set['jenkins']['master']['endpoint'] = "http://#{jenkinsMaster.ipaddress}:#{jenkinsMaster.jenkins.master.port}"`
# under jenkins.master
    # host: localhost
    # listen_address: 0.0.0.0
    # port: 8080
    # endpoint: http://localhost:8080
# keep endpoint at localhost (stay in VPC), must set this for reverse proxy to work
template "#{node['jenkins']['master']['home']}/jenkins.model.JenkinsLocationConfiguration.xml" do
  source 'jenkins.model.JenkinsLocationConfiguration.xml.erb'
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  variables({
    :adminAddress => node['master']['adminAddress'],
    :jenkinsUrl   => node['master']['jenkinsUrl']
  })
end

# nginx reverse proxy setup, in concert with JenkinsLocationConfiguration above
include_recipe 'scala-jenkins-infra::_master-init-proxy'

%w(ssh-credentials job-dsl build-flow-plugin rebuild greenballs build-timeout copyartifact email-ext slack throttle-concurrents dashboard-view parameterized-trigger).each do |plugin|
  plugin, version = plugin.split('=') # in case we decide to pin versions later
  jenkins_plugin plugin
end

# restart jenkins (TODO: wait for it to come back up, so we can continue automatically with next recipes; until then, manually)
# Theory for observed failure: github-oauth plugin needs restart
# next steps: add scala-jenkins-infra::master-auth-github, and scala-jenkins-infra::master-workers (once they are up) to run_list
jenkins_plugin "github-oauth" do
  # To be sure, do safe restart (see subscribes below), since we're running chef every thirty minutes
end

jenkins_command 'safe-restart' do
  action :nothing
  subscribes :execute, 'jenkins_plugin[github-oauth]', :immediately
end
