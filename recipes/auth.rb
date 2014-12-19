#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: auth
#
# Configures Authentication.

# This is just for  this example work to, get the keys from a secure location
#  These keys are for the 'chef' Jenkins user to interact with the Jenkins API.
#  Create a public/private key pair.
unless node['jenkins']['executor']['private_key']
  require 'net/ssh'
  key = OpenSSL::PKey::RSA.new(4096)
  # Set them in our cookbook scope till Jenkins is ready to use them.
  node.set['master']['user']['private_key'] = key.to_pem
  node.set['master']['user']['public_key'] =
    "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
end

# Creates the 'scala-jenkins' Jenkins user and associates the public key
#  Needs anonymous auth to create a user, to then use this users there after.
#  See Caveats: https://github.com/opscode-cookbooks/jenkins#caveats
jenkins_user 'scala-jenkins' do
  full_name   'Automation'
  public_keys [ node['master']['user']['public_key'] ]
end

# Set the private key on the Jenkins executor, must be done only after the user
#  has been created, otherwise API will require authentication and not be able
#  to create the user.
ruby_block 'set private key' do
  block do
    node.set['jenkins']['executor']['private_key'] =
    node['master']['user']['private_key']
  end
end

# If auth scheme is set, include recipe with that implementation.
if node['master']['auth']
  include_recipe "scala-jenkins-infra::_auth-#{node['master']['auth']}"
end
