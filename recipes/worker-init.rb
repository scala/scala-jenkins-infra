#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-init
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe "scala-jenkins-infra::_config-ebs"

include_recipe 'scala-jenkins-infra::_init-chef-client'

include_recipe "git" unless platform_family?("windows")

include_recipe "sbt-extras"

include_recipe "scala-jenkins-infra::_worker-init-#{node["platform_family"]}"

include_recipe "scala-jenkins-infra::_jvm-select"

# The bit from chef-sbt that's missing in chef-sbt-extras...
# (Easily find the launcher jar for those paranoid jobs that want to invoke sbt using the java command
#  could update those scripts to use sbt-extras more carefully, I suppose.)
# TODO: remove and rework scripts
remote_file "#{node['sbt']['launcher_path']}" do
  source "https://repo.lightbend.com/typesafe/ivy-releases/org.scala-sbt/sbt-launch/#{node['sbt']['version']}/sbt-launch.jar"
  action :create
  owner "root"
  group "root"
  mode 0755
end