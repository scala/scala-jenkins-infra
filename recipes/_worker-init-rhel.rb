#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-debian
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

cookbook_file "epel-apache-maven.repo.erb" do
  owner 'root'
  path "/etc/yum.repos.d/epel-apache-maven.repo"
end

%w{java-1.7.0-openjdk-devel java-1.8.0-openjdk-devel ant ant-contrib ant-junit apache-maven}.each do |pkg|
  package pkg
end

# NOTE: MUST BE LAST -- it selects the chef-configured jdk (the above packages install openjdk 7 & 8, but we want something else)
include_recipe "java"

# /usr/bin/build-classpath: error: JVM_LIBDIR /usr/lib/jvm-exports/java does not exist or is not a directory
# http://www.karakas-online.de/forum/viewtopic.php?t=9781
# JAVA_HOME=/usr/lib/jvm/java implies there must be a /usr/lib/jvm-exports/java, which is not created by the oracle rpm
directory '/usr/lib/jvm-exports/java'
