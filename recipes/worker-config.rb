#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: worker-config
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# This can only be run *after* bootstrap due to vault dependency.

include_recipe "scala-jenkins-infra::_config-adminKeys" unless platform_family?("windows")

node["jenkinsHomes"].each do |jenkinsHome, workerConfig|
  case node["platform_family"]
  when "windows"
    # the regular resource approach does not work for me
    execute 'create jenkins user' do
      command "net user /ADD #{workerConfig["jenkinsUser"]}"
      not_if  "net user #{workerConfig["jenkinsUser"]}"
    end
  else
    user workerConfig["jenkinsUser"] do
      home jenkinsHome
    end
  end

  directory jenkinsHome do
    owner workerConfig["jenkinsUser"]
#    mode 00755  -- TODO: enable on linux, but NOT on windows, as it causes permissions problems (no idea how to fix)
    action :create
  end

  directory "#{jenkinsHome}/.ssh" do
    owner workerConfig["jenkinsUser"]
#    mode  '700' -- TODO: enable on linux, but NOT on windows, as it causes permissions problems (no idea how to fix)
  end

  # for use by java.io.tmpdir since /tmp may not have enough space
  directory "#{jenkinsHome}/tmp" do
    owner workerConfig["jenkinsUser"]
  end

  file "#{jenkinsHome}/.ssh/authorized_keys" do
    owner workerConfig["jenkinsUser"]
    mode  '600'
    content chef_vault_item("master", "scala-jenkins-keypair")['public_key'] + "\n#{node['authorized_keys']['jenkins']}"
  end


  case node["platform_family"]
  when "windows"
    # also sets core.longpaths true
    # without longpaths enabled we have:
    # - known problems with `git clean -fdx` failing
    # - suspected problems with intermittent build failures due to
    #   very long paths to some classfiles
    cookbook_file 'gitconfig-windows' do
      path "#{jenkinsHome}/.gitconfig"
    end
  else
    git_user workerConfig["jenkinsUser"] do
      home        jenkinsHome
      full_name   'Scala Jenkins'
      email       'adriaan@lightbend.com'
    end
  end
end


include_recipe "scala-jenkins-infra::_worker-config-#{node["platform_family"]}"
