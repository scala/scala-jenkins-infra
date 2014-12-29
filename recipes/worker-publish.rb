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

jenkinsHome = "/home/jenkins-priv"
jenkinsUser = "jenkins-priv"

node.set["jenkinsHomes"][jenkinsHome]["env"]["sshCharaArgs"] = "(\"scalatest@chara.epfl.ch\" \"-i\" \"#{jenkinsHome}/.ssh/for_chara\")"

# TODO: recursive doesn't set owner correctly (???), so list out all dirs explicitly
["#{jenkinsHome}/.ssh", "#{jenkinsHome}/.ivy2", "#{jenkinsHome}/.m2", "#{jenkinsHome}/.sbt", "#{jenkinsHome}/.sbt/0.13", "#{jenkinsHome}/.sbt/0.13/plugins/"].each do |dir|
  directory dir do
    user jenkinsUser
  end
end

file "#{jenkinsHome}/.ssh/for_chara" do
  owner jenkinsUser
  mode '600'
  content ChefVault::Item.load("worker-publish", "chara-keypair")['private_key']
end

execute 'accept chara host key' do
  command "ssh -oStrictHostKeyChecking=no scalatest@chara.epfl.ch -i \"#{jenkinsHome}/.ssh/for_chara\" true"
  user jenkinsUser
  #
  # not_if "grep -qs \"#{ChefVault::Item.load("worker-publish", "chara-keypair")['public_key']}\" #{jenkinsHome}/.ssh/known_hosts"
end

{ "#{jenkinsHome}/.credentials-private-repo" => "credentials-private-repo.erb",
  "#{jenkinsHome}/.credentials"              => "credentials.erb",
  "#{jenkinsHome}/.sonatype-curl"            => "sonatype-curl.erb",
  "#{jenkinsHome}/.s3credentials"            => "s3credentials.erb",
  "#{jenkinsHome}/.m2/settings.xml"          => "m2-settings.xml.erb"
}.each do |target, templ|
  template target do
    source templ
    user jenkinsUser
    sensitive true

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
  user jenkinsUser
end

%w{zip xz-utils rpm dpkg lintian fakeroot}.each do |pkg|
  package pkg
end
