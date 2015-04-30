#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-config-rhel
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

require 'cgi'

node["jenkinsHomes"].each do |jenkinsHome, workerConfig|
  jenkinsUser=workerConfig["jenkinsUser"]

  ["#{jenkinsHome}/.m2"].each do |dir|
    directory dir do
      user jenkinsUser
    end
  end

  { "#{jenkinsHome}/.m2/settings.xml" => "m2-settings-public-jobs.xml.erb",
    "#{jenkinsHome}/.credentials"     => "credentials-public-jobs.erb"
  }.each do |target, templ|
    template target do
      source templ
      user jenkinsUser
      sensitive true

      variables({
        :privateRepoPass => chef_vault_item("worker", "private-repo-public-jobs")['pass'],
        :privateRepoUser => chef_vault_item("worker", "private-repo-public-jobs")['user']
      })
      helpers(ScalaJenkinsInfra::JobBlurbs)
    end
  end
end