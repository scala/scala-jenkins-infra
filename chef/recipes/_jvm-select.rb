#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _jvm-select
#
# Copyright 2015, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

directory "/usr/local/share/jvm/" do
  mode '755'
  recursive true
end

%w{jvm-select}.each do |f|
  cookbook_file f do
    mode '755'
    path "/usr/local/share/jvm/#{f}"
  end
end