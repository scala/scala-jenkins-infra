#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-init-windows
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'windows'

# TODO: not idempotent (must stop jenkins slave service before re-installing jdk)
# hacked around by not re-installing java when javac of the right version is found
# needed for other stuff (install ruby etc)

# def checkJavacVersion
#   javac = File.join(node['java']['java_home'], "bin", "javac.exe")
#   javacVersion = ""
#   if File.exists?(javac)
#     # http://stackoverflow.com/a/1666103/276895
#     IO.popen(javac+" -version 2>&1") do |pipe| # Redirection is performed using operators
#       pipe.sync = true
#       while str = pipe.gets
#         javacVersion = javacVersion + str # This is synchronous!
#       end
#     end
#   end
#   javacVersion.chop
# end

# include_recipe "java" if checkJavacVersion != node['java']['javacVersion']

ruby_block 'Add Embedded Bin Path' do
  block do
    ENV['PATH'] += ';C:/opscode/chef/embedded/bin'
  end
  action :nothing
end

# using security groups instead
execute "no-win-firewall" do
  command "NetSh Advfirewall set allprofiles state off"
end
