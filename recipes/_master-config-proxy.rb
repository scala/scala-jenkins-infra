#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-proxy
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# TODO further optimize based on https://wiki.jenkins-ci.org/display/JENKINS/Running+Hudson+behind+Nginx

# Set up a reverse proxy to allow jenkins to run on port 80

package "nginx"

user "nginx"

template '/etc/nginx/nginx.conf' do
  source 'nginx.conf'
  notifies :reload, "service[nginx]"
end

template '/etc/nginx/conf.d/jenkins.conf' do
  source 'nginx-jenkins.conf'
  notifies :reload, "service[nginx]"
end

directory "/etc/nginx/ssl"

cookbook_file "scala-ci.crt" do
  owner 'root'
  path "/etc/nginx/ssl/scala-ci.crt"
end

cookbook_file "dhparam.pem" do
  owner 'root'
  path "/etc/nginx/ssl/dhparam.pem"
end


file "/etc/nginx/ssl/scala-ci.key" do
  owner 'root'
  mode  '600'
  content chef_vault_item("master", "scala-ci-key")['private_key']
  sensitive true
end


service 'nginx' do
  action :start
end
