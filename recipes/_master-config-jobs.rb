#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-jobs
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

# TODO: auto-discover templates, organize them in views according to subdirs under templates/defaults
# run_context.cookbook_collection[cookbook_name].manifest[:templates] is an array of
# {"name"=>"scala-release-2.11.x-unix.xml.erb",
# "path"=>"templates/default/scala-release-2.11.x/scala-release-2.11.x-unix.xml.erb", ...}

%w(scala-release-2.11.x scala-release-2.11.x-build scala-release-2.11.x-unix scala-release-2.11.x-windows scala-release-2.11.x-smoketest scala-release-2.11.x-scala-lang scala-release-2.11.x-scala-lang-update-current).each do |name|
  xml = File.join(Chef::Config[:file_cache_path], "#{name}.xml")

  template xml do
    source "scala-release-2.11.x/#{name}.xml.erb"
    helpers(ScalaJenkinsInfra::JobBlurbs)
  end

  jenkins_job name do
    config xml
  end
end
