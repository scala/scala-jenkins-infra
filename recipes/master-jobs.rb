#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-jobs
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

%w(scala-release-2.11.x scala-release-2.11.x-build scala-release-2.11.x-unix scala-release-2.11.x-windows scala-release-2.11.x-smoketest scala-release-2.11.x-scala-lang scala-release-scala-lang-update-current).each do |name|
  xml = File.join(Chef::Config[:file_cache_path], "#{name}.xml")

  template xml do
    source "#{name}.xml.erb"
    helpers(ScalaJenkinsInfra::JobBlurbs)
  end

  jenkins_job name do
    config xml
  end
end
