#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-config-windows-cygwin
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

# TODO: submit PRs to upstream cookbook

### CYGWIN + sshd

# first download base system, because installer fails to download in unattended mode
# windows_zipfile needs chef_gem[rubyzip], which fails when run during bootstrap (PATH messed up?)
windows_zipfile "cygwin-base" do
  path      Chef::Config[:file_cache_path]
  source    node['cygwin']['base']['url']
  checksum  node['cygwin']['base']['checksum']
  overwrite true

  action :unzip
end

# the above unzips to this directory
cygPackages = File.join(Chef::Config[:file_cache_path], "cygwin")

remote_file "#{Chef::Config[:file_cache_path]}/cygwin-setup.exe" do
  source node['cygwin']['installer']['url']
  action :create_if_missing
end

execute "cygwin-setup" do
  cwd     Chef::Config[:file_cache_path]
  command "cygwin-setup.exe -q -L -l #{cygPackages} -O -R #{node['cygwin']['home']} -P openssh,cygrunsrv"
end

windows_path "#{node['cygwin']['home']}\\bin" do
  action :add
end

# map /home and /tmp to ephemeral storage (local ssd)
file "#{node['cygwin']['home']}/etc/fstab" do
  content <<-EOH.gsub(/^    /, '')
    none /cygdrive cygdrive binary,posix=0,user 0 0
    Y: /home ntfs binary 0 0
  EOH
end

cygbash="#{node['cygwin']['home']}/bin/bash.exe"

require 'securerandom'
bash 'configure sshd' do
  interpreter cygbash
  environment ({'SHELLOPTS' => 'igncr'})

  code   "ssh-host-config -y -u cyg_server -w #{SecureRandom.base64}"
  not_if "cygrunsrv --query sshd | grep Running"
end

bash 'start sshd' do
  interpreter cygbash
  environment ({'SHELLOPTS' => 'igncr'})

  code   "cygrunsrv --start sshd"
  not_if "cygrunsrv --query sshd | grep Running"
end

include_recipe 'windows::reboot_handler'

# needed to allow pubkey login on windows
# this needs a reboot!
bash 'config lsa' do
  interpreter cygbash
  environment ({'SHELLOPTS' => 'igncr'})

  code   'auto_answer="yes" cyglsa-config'
  not_if "regtool get '/HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Control/Lsa/Authentication Packages' | grep cyglsa"

  notifies :request, 'windows_reboot[7]', :delayed
end

bash 'git config' do
  interpreter cygbash
  # without longpaths enabled we have:
  # - known problems with `git clean -fdx` failing
  # - suspected problems with intermittent build failures due to
  #   very long paths to some classfiles
  code "git config --global core.longpaths true"
end

windows_reboot 7 do
  timeout 7
  reason 'Restarting computer in 7 seconds!'
  action :nothing
end
