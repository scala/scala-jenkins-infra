#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-config-windows
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#


node["jenkinsHomes"].each do |jenkinsHome, workerConfig|
  if workerConfig["publish"]
    s3Downloads = chef_vault_item("worker-publish", "s3-downloads")

    # TODO: once s3-plugin supports it, use instance profile instead of credentials
    {
      "#{jenkinsHome}/.s3credentials" => "s3credentials.erb"
    }.each do |target, templ|
      template target do
        source    templ
        sensitive true
        user      workerConfig["jenkinsUser"]

        variables({
          :s3Downloads => s3Downloads
        })
      end
    end

    # (only) needed for WIX ICE validation (http://windows-installer-xml-wix-toolset.687559.n2.nabble.com/Wix-3-5-amp-Cruise-Control-gives-errorLGHT0217-td6039205.html#a6039814)
    # wix was failing, added jenkins to this group, rebooted (required!), then it worked
    group "Administrators" do
      action :modify
      members workerConfig["jenkinsUser"]
      append true
    end
  end
end

# cygwin must be installed manually...  C:\Users\Administrator\AppData\Local\Temp\Cygwin\2.7.0\setup-x86_64.exe" --site http://mirrors.kernel.org/sourceware/cygwin/ --packages default --root C:\tools\cygwin --local-package-dir C:\tools\cygwin
#chocolatey_package 'openssh' do
#  options '--params="/SSHServerFeature"'
#end

chocolatey_package 'git'
chocolatey_package 'jdk8' # manually installed jdk-6u45-windows-x64 (have to explicitly select all packages or it won't install the jdk)
chocolatey_package 'ant' do
  version "1.9.8" # 1.10 needs jdk8, which is no go for 2.11
end


chocolatey_package 'wixtoolset' do
  options '--allow-empty-checksums'
  action [:install]
end


include_recipe 'scala-jenkins-infra::_worker-config-windows-cygwin'
