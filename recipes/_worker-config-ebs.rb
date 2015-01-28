#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-config-ebs
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

jenkinsHome="/home/jenkins"
jenkinsUser="jenkins"
jenkinsDev="/dev/sdj"
jenkinsFs="ext4"

aws_ebs_volume jenkinsDev do
  size 100
  device jenkinsDev
  volume_type "gp2"
  availability_zone node[:ec2][:placement_availability_zone]
  action [:create, :attach]
end

execute 'mkfs' do
  command "mkfs -t #{jenkinsFs} #{jenkinsDev}"
  not_if do
    BlockDevice.wait_for(jenkinsDev)
    system("blkid -s TYPE -o value #{jenkinsDev}")
  end
end

directory jenkinsHome do
  owner jenkinsUser
  action :create
  mode 0755
end

mount jenkinsHome do
  device jenkinsDev
  fstype jenkinsFs
  options 'noatime'
  action [:mount, :enable]
end