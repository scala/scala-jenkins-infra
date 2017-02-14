#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-debian
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "git"

include_recipe "apt" # do apt-get update

include_recipe "sbt-extras"

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

include_recipe "nodejs"  # for Scala.js

include_recipe "scala-jenkins-infra::_java_packages"

# NOTE: MUST BE LAST -- it selects the chef-configured jdk (the above packages install openjdk 7 & 8, but we want something else)
include_recipe "java"
