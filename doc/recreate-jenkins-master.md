# How to recreate jenkins-master from scratch
(Say, if you accidentally terminated it by doing a `shutdown -h now` :scream: That won't happen again because termination behavior is now stop, and protection is enabled..... :sweat: )

On EC2 (could use `knife server ec2 create`, but did manually): 
Create an m4.large instance from ami-23e8a343 (amzn-ami-hvm-2016.09.0.20161028-x86_64-gp2)
  - Name: jenkins-master
  - VPC ID vpc-99b04cfc
  - Availability zone us-west-1c
  - Subnet ID: subnet-4bb3b80d
  - Security groups: Master
  - IAM role: jenkins-master
  - Key pair name: adriaan-scripts
  - Root device type: ebs
  - Termination protection: True
  - Virtualization: hvm
  - Attach elastic ip 54.67.111.226

ssh jenkins-master, become root:
```
chown jenkins:jenkins -R /var/lib/jenkins
chown artifactory -R /var/lib/artifactory
wget https://packages.chef.io/stable/el/5/chef-server-core-12.6.0-1.el5.x86_64.rpm
rpm -Uvh chef-server-core-12.6.0-1.el5.x86_64.rpm
```

On your own machine, from ~/git/cookbooks/scala-jenkins-infra (Which has knife config)

```
knife node edit jenkins-master # save json config -- important! has EBS volume info
knife node delete jenkins-master
knife bootstrap jenkins-master -N jenkins-master --ssh-user ec2-user --identity-file ~/.ssh/typesafe-scala-aws-adriaan-scripts.pem --sudo
knife node edit jenkins-master # restore json config obtained above (sets runlist and attributes)
# subsumed by restoring:
# knife node run_list set jenkins-master  "recipe[chef-vault],scala-jenkins-infra::master-init,scala-jenkins-infra::master-config,scala-jenkins-infra::master-jenkins,scala-jenkins-infra::master-scabot"
# refresh vault since public key changed:
for i in $(knife vault show master); do knife vault refresh master $i; done
```

ssh to jenkins-master, become root:
```
chef-client
/etc/init.d/jenkins restart
/etc/init.d/artifactory restart
chef-client

# repeat a couple times
```


For reference, jenkins-master's attributes:
```
{
  "tags": [],
  "sbt-extras": {
    "user_home_basedir": "/home"
  },
  "java": {
    "jdk_version": 8
  },
  "aws": {
    "ebs_volume": {
      "/dev/sdj": {
        "volume_id": "vol-1ce1a901"
      },
      "/dev/sdk": {
        "volume_id": "vol-1fe1a902"
      }
    }
  },
  "chef_client": {
    "cron": {
      "environment_variables": "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    }
  }
}
```
