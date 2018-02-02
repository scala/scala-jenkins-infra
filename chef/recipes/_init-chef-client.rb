#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _init-chef-client
#
# Copyright 2015, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# location is platform dependent (ubuntu/amazon/window)
sslCertFile = ['/etc/ssl/certs/ca-certificates.crt', '/etc/ssl/certs/ca-bundle.crt', 'c:\opscode\chef\embedded\ssl\certs\cacert.pem'].find{|p| File.exist?(p)}

# for good measure, in case magic_shell_environment's modifications don't make it to the shell used by cron...
if sslCertFile != nil
 node.set['chef_client']['cron']['environment_variables']="SSL_CERT_FILE=#{sslCertFile}"
end

# set SSL_CERT_FILE so that ruby's openssl can connect to aws etc... URGH
# NOTE will need a reboot....
case node["platform_family"]
when "windows"
  env "SSL_CERT_FILE" do
    value   sslCertFile
    only_if {sslCertFile != nil}
  end
else
  magic_shell_environment 'SSL_CERT_FILE' do
    value   sslCertFile
    only_if {sslCertFile != nil}
  end
end

# has no effect!?
# ruby_block 'Set SSL_CERT_FILE' do
#   block do
#     ENV['SSL_CERT_FILE'] = sslCertFile
#   end
#   only_if {sslCertFile != nil}
# end

include_recipe 'chef-client::service'
