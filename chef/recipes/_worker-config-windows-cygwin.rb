#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-config-windows-cygwin
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

### CYGWIN: manual install, need packages openssh, curl

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

