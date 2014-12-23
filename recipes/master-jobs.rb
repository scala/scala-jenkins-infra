#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: master-jobs
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

chef_gem "chef-vault"
require "chef-vault"

ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
  end
end

windowsBlurb = <<-EOH.gsub(/^ {2}/, '')
  #!C:/cygwin/bin/bash -ex
  set -o igncr # ignore crlf issues on cygwin

  source scripts/jobs/$JOB_NAME
EOH

linuxBlurb = <<-EOH.gsub(/^ {2}/, '')
  #!/bin/bash -ex

  source scripts/jobs/$JOB_NAME
EOH


%w(scala-release-2.11.x-dist scala-release-2.11.x-scala-lang scala-release-2.11.x-smoketest scala-release-2.11.x-unix scala-release-2.11.x-windows scala-release-2.11.x scala-release-scala-lang-update-current).each do |name|
  xml = File.join(Chef::Config[:file_cache_path], "#{name}.xml")

  template xml do
    source "#{name}.xml.erb"

    variables({
      :jobShellBlurb        => linuxBlurb,
      :jobShellBlurbWindows => windowsBlurb
    })
  end

  jenkins_job name do
    config xml
  end
end
