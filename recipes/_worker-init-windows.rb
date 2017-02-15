#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-windows
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#


include_recipe 'windows'

include_recipe 'chocolatey'

# using security groups instead
execute "no-win-firewall" do
  command "NetSh Advfirewall set allprofiles state off"
end


directory 'C:\sbt'

# include_recipe "sbt-extras"

# The bit from chef-sbt that's missing in chef-sbt-extras...
# (Easily find the launcher jar for those paranoid jobs that want to invoke sbt using the java command
#  could update those scripts to use sbt-extras more carefully, I suppose.)
# TODO: remove and rework scripts
remote_file "#{node['sbt']['launcher_path']}" do
  source "https://repo.lightbend.com/typesafe/ivy-releases/org.scala-sbt/sbt-launch/#{node['sbt']['version']}/sbt-launch.jar"
  action :create
  mode 0755
end
