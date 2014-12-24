#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
chef_gem "chef-vault"
require "chef-vault"

node.set["worker"]["labels"] = node["worker"]["labels"] + ["publish"]

jenkinsHome = "/home/jenkins"

file "#{jenkinsHome}/.ssh/authorized_keys" do
  owner 'jenkins'
  mode '644'
  content ChefVault::Item.load("master", "scala-jenkins-keypair")['public_key'] #.join("\n")
end

file "#{jenkinsHome}/.ssh/for_chara" do
  owner 'jenkins'
  mode '600'
  content ChefVault::Item.load("worker-publish", "chara-keypair")['private_key']
end


# TODO: verify that all directories are owned by the jenkins user (this is why I have the redundant #{jenkinsHome}/.sbt/0.13)
["#{jenkinsHome}/.ivy2", "#{jenkinsHome}/.m2", "#{jenkinsHome}/.sbt/0.13", "#{jenkinsHome}/.sbt/0.13/plugins/"].each do |dir|
  directory dir do
    user node['jenkins']['master']['user']
    group node['jenkins']['master']['group']
    recursive true
  end
end

{ "#{jenkinsHome}/.credentials-private-repo" => "credentials-private-repo.erb",
  "#{jenkinsHome}/.credentials"              => "credentials.erb",
  "#{jenkinsHome}/.sonatype-curl"            => "sonatype-curl.erb",
  "#{jenkinsHome}/.s3credentials"            => "s3credentials.erb",
  "#{jenkinsHome}/.m2/settings.xml"          => "m2-settings.xml.erb"
}.each do |target, templ|
  template target do
    source templ
    user node['jenkins']['master']['user']
    group node['jenkins']['master']['group']

    variables({
      :sonatypePass    => ChefVault::Item.load("worker-publish", "sonatype")['pass'],
      :sonatypeUser    => ChefVault::Item.load("worker-publish", "sonatype")['user'],
      :privateRepoPass => ChefVault::Item.load("worker-publish", "private-repo")['pass'],
      :privateRepoUser => ChefVault::Item.load("worker-publish", "private-repo")['user'],
      :s3DownloadsPass => ChefVault::Item.load("worker-publish", "s3-downloads")['pass'],
      :s3DownloadsUser => ChefVault::Item.load("worker-publish", "s3-downloads")['user']
    })
  end
end

template "#{jenkinsHome}/.sbt/0.13/plugins/gpg.sbt" do
  source "sbt-0.13-plugins-gpg.sbt.erb"
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
end

%w{zip xz-utils rpm dpkg lintian fakeroot}.each do |pkg|
  package pkg
end
