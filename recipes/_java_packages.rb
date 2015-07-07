#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _java_packages
#
# Copyright 2015, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# oracle 6 is installed by default on workers using the java package
(platform_family?('debian') ? %w{openjdk-7-jdk openjdk-8-jdk} : %w{java-1.7.0-openjdk-devel java-1.8.0-openjdk-devel}).each do |pkg|
  package pkg
end

