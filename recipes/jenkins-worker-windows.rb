#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: jenkins-worker-windows
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# needed for other stuff (install ruby etc)
include_recipe 'aws'
include_recipe 'windows'

# it's the includes that actually cause these recipes to contribute to the run list
include_recipe "java"
include_recipe "git"
include_recipe "chef-sbt"

# ??? must come later or it won't find ruby.exe, which is installed by git?
include_recipe "wix"

# include_recipe 'jenkins'

# for the jenkins recipe: ensure_update_center_present! bombs without it (https://github.com/opscode-cookbooks/jenkins/issues/305)
ruby_block 'Enable ruby ssl on windows' do
  block do
    ENV[SSL_CERT_FILE] = 'c:\opscode\chef\embedded\ssl\certs\cacert.pem'
  end
  action :nothing
end

# jenkins_jnlp_slave 'builder' do
#   remote_fs 'C:\jenkins'
#   user      'Administrator'
#   labels    ['builder', 'windows']
#
#   environment(
#     WIX:         "",
#     sbtLauncher: "",
#     JAVA_OPTS:   "-Xms1536M -Xmx1536M -Xss1M -XX:MaxPermSize=256M -XX:ReservedCodeCacheSize=128M -XX:+UseParallelGC -XX:+UseCompressedOops",
#     ANT_OPTS:    "-Xms1536M -Xmx1536M -Xss1M -XX:MaxPermSize=256M -XX:ReservedCodeCacheSize=128M -XX:+UseParallelGC  -XX:+UseCompressedOops")
# end