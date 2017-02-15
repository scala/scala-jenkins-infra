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
# windows_zipfile "cygwin-base" do
#   path      Chef::Config[:file_cache_path]
#   source    node['cygwin']['base']['url']
#   checksum  node['cygwin']['base']['checksum']
#   overwrite true
#
#   action :unzip
# end
#
# # the above unzips to this directory
# cygPackages = File.join(Chef::Config[:file_cache_path], "cygwin")
#
# remote_file "#{Chef::Config[:file_cache_path]}/cygwin-setup.exe" do
#   source node['cygwin']['installer']['url']
#   action :create_if_missing
# end
#
# execute "cygwin-setup" do
#   cwd     Chef::Config[:file_cache_path]
#   command "cygwin-setup.exe -q -L -l #{cygPackages} -O -R #{node['cygwin']['home']} -P openssh,cygrunsrv"
# end

windows_path "#{node['cygwin']['home']}\\bin" do
  action :add
end

# map /home to a separate volume
file "#{node['cygwin']['home']}/etc/fstab" do
  content <<-EOH.gsub(/^    /, '')
    none /cygdrive cygdrive binary,posix=0,user 0 0
    Y: /home ntfs binary 0 0
  EOH
end

cygbash="#{node['cygwin']['home']}/bin/bash.exe"

# ssh-host-config takes care of setting up the user account for Tcb and other privileges needed for pubkey auth via LSA
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

# IMPORTANT NOTE: /etc/sshd_config should have:
# ```
# StrictModes no
# PubkeyAuthentication yes
# ```

# needed to allow pubkey login on windows
# this needs a reboot!
bash 'config lsa' do
  interpreter cygbash
  environment ({'SHELLOPTS' => 'igncr'})

  code   'auto_answer="yes" cyglsa-config'
  not_if "regtool get '/HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Control/Lsa/Authentication Packages' | grep cyglsa"
end

# IMPORTANT MANUAL STEP: REBOOT -- LSA install won't take effect until after a reboot

