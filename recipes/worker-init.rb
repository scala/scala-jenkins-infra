#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-init
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'scala-jenkins-infra::_init-chef-client'

include_recipe "aws"

include_recipe "git"

include_recipe "chef-sbt" # TODO: remove, redundant with sbt-extras, but the latter won't work on windows
include_recipe "sbt-extras" unless platform_family?("windows")

include_recipe "scala-jenkins-infra::_worker-init-#{node["platform_family"]}"

directory "/usr/local/share/jvm/" do
  mode '755'
  recursive true
end

%w{jvm-select jvm-select-common}.each do |f|
  cookbook_file f do
    mode '755'
    path "/usr/local/share/jvm/#{f}"
  end
end