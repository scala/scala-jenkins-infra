#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-jobs
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

%w(scala-release-2.11.x-dist scala-release-2.11.x-scala-lang scala-release-2.11.x-smoketest scala-release-2.11.x-unix scala-release-2.11.x-windows scala-release-2.11.x scala-release-scala-lang-update-current).each do |name|
  xml = File.join(Chef::Config[:file_cache_path], "#{name}.xml")

  template xml do
    source "#{name}.xml.erb"
  end

  jenkins_job name do
    config xml
  end
end