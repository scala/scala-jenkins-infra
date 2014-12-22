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

jenkinsHome = "~jenkins"

["#{jenkinsHome}/.ivy2", "#{jenkinsHome}/.m2", "#{jenkinsHome}/.sbt/0.13/plugins/"].each do |dir|
  directory dir do
    user node['jenkins']['master']['user']
    group node['jenkins']['master']['group']
    recursive true
  end
end

{ "#{jenkinsHome}/.ivy2/.credentials-private-repo" => "ivy2-credentials-private-repo.erb",
  "#{jenkinsHome}/.ivy2/.credentials"              => "ivy2-credentials.erb",
  "#{jenkinsHome}/.m2/settings.xml"                => "m2-settings.xml.erb",
  "#{jenkinsHome}/.sonatype-curl"                  => "sonatype-curl.erb"
}.each do |target, templ|
  template target do
    source templ
    user node['jenkins']['master']['user']
    group node['jenkins']['master']['group']

    variables({
      :sonatypePass    => ChefVault::Item.load("worker-publish", "sonatype")['pass'],
      :sonatypeUser    => ChefVault::Item.load("worker-publish", "sonatype")['user'],
      :privateRepoPass => ChefVault::Item.load("worker-publish", "private-repo")['pass'],
      :privateRepoUser => ChefVault::Item.load("worker-publish", "private-repo")['user']
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