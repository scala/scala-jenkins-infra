#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _worker-config-ebs
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

node['ebs']['volumes'].each do |mountPoint, ebsConfig|
  aws_ebs_volume ebsConfig['dev'] do
    size    ebsConfig['size']
    device  ebsConfig['dev']

    volume_type "gp2"
    availability_zone node[:ec2][:placement_availability_zone]
    action [:create, :attach]
  end

  case node["platform_family"]
  when "windows"
    force="" # set to "NOERR" to force partitioning&formatting the disk
    diskpartScript=<<-EOX.gsub(/^    /, '')
    select disk #{ebsConfig['disk']}
    attributes disk clear readonly
    online disk #{force}
    create partition primary #{force}
    select partition 1
    format FS=#{ebsConfig['fstype']} quick
    assign LETTER=#{mountPoint}
    EOX
    script "setupdisk" do
      interpreter "diskpart"
      flags "/s"
      code diskpartScript
      not_if { ::File.directory?("#{mountPoint}:\\") }
    end
  else
    execute 'mkfs' do
      command "mkfs -t #{ebsConfig['fstype']} #{ebsConfig['dev']}"
      not_if do
        BlockDevice.wait_for(ebsConfig['dev'])
        system("blkid -s TYPE -o value #{ebsConfig['dev']}")
      end
    end

    directory mountPoint do
      owner ebsConfig['user']
      mode 0755

      action :create
    end

    mount mountPoint do
      device  ebsConfig['dev']
      fstype  ebsConfig['fstype']
      options ebsConfig['mountopts']

      action [:mount, :enable]
    end
  end
end