#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-debian
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "java"

# /usr/bin/build-classpath: error: JVM_LIBDIR /usr/lib/jvm-exports/java does not exist or is not a directory
# http://www.karakas-online.de/forum/viewtopic.php?t=9781
# JAVA_HOME=/usr/lib/jvm/java implies there must be a /usr/lib/jvm-exports/java, which is not created by the oracle rpm
directory '/usr/lib/jvm-exports/java'

cookbook_file "epel-apache-maven.repo.erb" do
  owner 'root'
  path "/etc/yum.repos.d/epel-apache-maven.repo"
end

%w{ant ant-contrib ant-junit apache-maven}.each do |pkg|
  package pkg
end
