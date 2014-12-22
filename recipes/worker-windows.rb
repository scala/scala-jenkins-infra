#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-windows
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# TODO: not idempotent (must stop jenkins slave service before re-installing jdk)


node.set['sbt']['script_name']   = 'sbt.bat'
node.set['sbt']['launcher_path'] = 'C:/sbt'
node.set['sbt']['bin_path']      = 'C:/sbt'

node.set["worker"]["env"]["sbtLauncher"] = File.join(node['sbt']['launcher_path'], "sbt-launcher.jar") # from chef-sbt cookbook
node.set["worker"]["env"]["WIX"]         = node["wix"]["home"]


# needed for other stuff (install ruby etc)
include_recipe 'aws'
include_recipe 'windows'

# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"
include_recipe "git"
include_recipe "chef-sbt"

# ??? must come later or it won't find ruby.exe, which is installed by git?
include_recipe "wix"

git_user 'jenkins' do
  full_name   'Scala Jenkins'
  email       'adriaan@typesafe.com'
end
