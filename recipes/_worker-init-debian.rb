#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-debian
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "java"

%w{ant ant-contrib ant-optional maven}.each do |pkg|
  package pkg
end
