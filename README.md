# Scala's Jenkins Cluster 
The idea is to use chef to configure EC2 instances for both the master and the slaves. The jenkins config will be captured in chef recipes. Everything is versioned, with server and workers not allowed to maintain state.

This is inspired by https://erichelgeson.github.io/blog/2014/05/10/automating-your-automation-federated-jenkins-with-chef/


# Get some tools
```
brew cask install awscli cord
```

# Create security group (ec2 firewall)

```
aws ec2 create-security-group --group-name "Windows" --description "Remote access to Windows instances" 
aws ec2 authorize-security-group-ingress --group-name "Windows" --protocol tcp --port 5985 --cidr $YOUR_LOCAL_IP/32 # allow WinRM from the machine that will execute `knife ec2 server create` below

aws ec2 authorize-security-group-ingress --group-name "Windows" --protocol tcp --port 3389 --cidr $YOUR_LOCAL_IP/32 # RDP (only for diagnosing)
```

```
aws ec2 create-security-group --group-name "Master" --description "Remote access to the Jenkins master" 
aws ec2 authorize-security-group-ingress --group-name "Master" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name "Master" --protocol tcp --port 8080 --cidr 0.0.0.0/0
```

aws ec2 create-security-group --group-name "Workers" --description "Jenkins workers nodes" 
aws ec2 authorize-security-group-ingress --group-name "Workers" --protocol tcp --port 22 --cidr $MACHINE-INITIATING-BOOTSTRAP/32
aws ec2 authorize-security-group-ingress --group-name "Workers" --protocol tcp --port 0-65535 --source-group Master

# Install chef/knife

```
brew cask install chefdk
eval "$(chef shell-init zsh)" # set up gem environment
gem install knife-ec2 knife-windows knife-github-cookbooks chef-vault
```

## Create chef.io organization 
https://manage.chef.io/organizations/typesafe-scala

download:
  - user key
  - org validation key
  - knife config (knife.rb)

## Get cookbooks

```
git init cookbooks
cd cookbooks
g commit --allow-empty -m"Initial" 
```

- knife cookbook site install wix 1.0.2 # newer versions don't work for me; also installs windows
- knife cookbook site install aws
- knife cookbook site install git
 
- move to unreleased versions on github:
  - knife cookbook github install opscode-cookbooks/windows    # fix nosuchmethoderror (#150)
  - knife cookbook github install adriaanm/java/windows-jdk1.6 # jdk 1.6 installer barfs on re-install -- wipe its INSTALLDIR
  - knife cookbook github install adriaanm/jenkins/fix305      # ssl fail on windows
  - knife cookbook github install adriaanm/scala-jenkins-infra
  - knife cookbook github install adriaanm/chef-sbt

- knife cookbook upload --all

## cache installers locally
- they are tricky to access, might disappear,...
- checksum is computed with `shasum -a 256`
- TODO: host them on an s3 bucket (credentials are available automatically)

# Launch instance on EC2 
## Create (ssh) key pair
```
echo $(aws ec2 create-key-pair --key-name chef | jq .KeyMaterial) | perl -pe 's/"//g' > ~/.ssh/chef.pem
chmod 0600 ~/.ssh/chef.pem
```

make sure `knife[:aws_ssh_key_id] = 'chef'` matches `--identity-file ~/.ssh/chef.pem`


## Select AMI

current windows: ami-cfa5b68a Windows_Server-2012-R2_RTM-English-64Bit-Base-2014.12.10
current linux-publisher: ami-b11b09f4 ubuntu/images-testing/hvm/ubuntu-trusty-daily-amd64-server-20141212

current linux (master/worker): ami-4b6f650e Amazon Linux AMI 2014.09.1 x86_64 HVM EBS


## Alternative windows AMIs
too stripped down (bootstraps in 8 min, though): ami-23a5b666 Windows_Server-2012-R2_RTM-English-64Bit-Core-2014.12.10
userdata.txt: `<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"} & netsh advfirewall firewall set rule group="remote administration" new enable=yes & netsh advfirewall firewall add rule name="WinRM Port" dir=in action=allow protocol=TCP  localport=5985</script>`

older: ami-e9a4b7ac amazon/Windows_Server-2008-SP2-English-64Bit-Base-2014.12.10
userdata.txt: '<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"}</script>'

older: ami-6b34252e Windows_Server-2008-R2_SP1-English-64Bit-Base-2014.11.19
doesn't work: ami-59a8bb1c Windows_Server-2003-R2_SP2-English-64Bit-Base-2014.12.10

## Bootstrap
NOTE: userdata.txt must be one line, no line endings (mac/windows issues?)

```
knife ec2 server create -N worker-windows \
   --region us-west-1 --flavor t2.medium -I ami-45332200 \
   -G Windows --user-data userdata.txt --bootstrap-protocol winrm \
   --identity-file ~/.ssh/chef.pem \
   --run-list "scala-jenkins-infra::worker-windows"
```


```
knife ec2 server create -N master \
   --region us-west-1 --flavor t2.small -I ami-4b6f650e \
   -G Master --sudo --ssh-user ec2-user \
   --identity-file ~/.ssh/chef.pem \
   --run-list "scala-jenkins-infra::master"
```

```
knife ec2 server create -N worker-linux-publish \
   --region us-west-1 --flavor t2.medium -I ami-b11b09f4 \
   -G Workers --ssh-user ubuntu \
   --identity-file ~/.ssh/chef.pem \
   --run-list "scala-jenkins-infra::worker-linux, scala-jenkins-infra::worker-publish"
```

-T jenkins-worker-publish

note: name can't be changed later, and duplicates aren't allowed (can bite when repeating knife ec2 create)


### Develop/test recipe

To re-run chef-client on windows

```
knife winrm $IP chef-client -m -P $PASSWORD
```

### set run-list (recipe to be executed by chef-client)

```
knife node run_list set worker-windows "scala-jenkins-infra::worker-windows"
``` 

### If the bootstrap didn't work at first, complete:
If it appears stuck at "Waiting for remote response before bootstrap.", the userdata didn't make it across 
(check C:\Program Files\Amazon\Ec2ConfigService\Logs) we need to enable unencrypted authentication:

```
aws ec2 get-password-data --instance-id $INST --priv-launch-key ~/.ssh/chef.pem

cord $IP, log in using password above and open a command line:

  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}

knife bootstrap -V windows winrm $IP

```




# Configuring the jenkins cluster
```
$ knife tag create master jenkins-master
Created tags jenkins-master for node master.
$ knife search tags:jenkins-master
1 items found

Node Name:   master
...

$ knife tag create worker-windows jenkins-worker

$ knife tag create worker-linux-publish jenkins-worker-publish
```

## Secure data
https://github.com/settings/applications/new -->
 - Authorization callback URL = http://ec2-54-67-28-42.us-west-1.compute.amazonaws.com:8080/securityRealm/finishLogin


from http://jtimberman.housepub.org/blog/2013/09/10/managing-secrets-with-chef-vault/

NOTE: the JSON must not have a field "id"!!!

### Chef user with keypair for jenkins cli access
```
eval "$(chef shell-init zsh)" # use chef's ruby, which has the net/ssh gem
ruby keypair.rb > keypair.json

knife vault create master scala-jenkins-keypair \
  --json keypair.json \
  --search 'tags:jenkins*' \
  --admins adriaan
```

### For github oauth

```
knife vault create master github-api \
  '{"client-id":"<Client ID>","client-secret":"<Client secret>"}' \
  --search 'tags:jenkins-master' \
  --admins adriaan
```

### Workers that need to publish
```
knife vault create worker-publish sonatype \
  '{"user":"XXX","pass":"XXX"}' \
  --search 'tags:jenkins-worker-publish' \
  --admins adriaan

knife vault create worker-publish private-repo \
  '{"user":"XXX","pass":"XXX"}' \
  --search 'tags:jenkins-worker-publish' \
  --admins adriaan
```

### Adding nodes that may access the vault items:

```
knife vault update worker-publish sonatype --search 'tags:jenkins-worker-publish'
knife vault update worker-publish private-repo --search 'tags:jenkins-worker-publish'
```