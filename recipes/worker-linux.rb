#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-linux
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

jenkinsHome = "/home/jenkins"

# TODO: rework attribute setting...
node.set['java']['jdk_version']    = '6'
node.set['java']['install_flavor'] = 'oracle' # partest's javap tests fail on openjdk...
node.set['java']['oracle']['accept_oracle_download_terms'] = true

# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"

include_recipe "git"
include_recipe "chef-sbt" # TODO: remove, redundant with sbt-extras, but the latter won't work on windows
include_recipe "sbt-extras"

node.set["worker"]["env"]["sbtLauncher"]  = File.join(node['sbt']['launcher_path'], "sbt-launch.jar") # from chef-sbt cookbook
node.set["worker"]["env"]["sbtCmd"]       = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
node.set["worker"]["env"]["sshCharaArgs"] = "(\"scalatest@chara.epfl.ch\" \"-i\" \"#{jenkinsHome}/.ssh/for_chara\")"
node.set["worker"]["env"]["JAVA_HOME"]    = node['java']['java_home'] # we get the jre if we don't do this
node.set["worker"]["labels"]              = ["linux"]

%w{ant}.each do |pkg|
  package pkg
end

user "jenkins" do
  home "/home/jenkins"
end

directory "/home/jenkins" do
  owner "jenkins"
  group "jenkins"
  mode 00755
  action :create
end

directory "/home/jenkins/.ssh" do
  owner "jenkins"
end

git_user 'jenkins' do
  full_name   'Scala Jenkins'
  email       'adriaan@typesafe.com'
end

