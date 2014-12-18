# Scala's Jenkins Cluster 
The idea is to use chef to configure EC2 instances for both the master and the slaves. The jenkins config will be captured in chef recipes. Everything is versioned, with server and workers not allowed to maintain state.

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

# get (ssh) key pair
echo $(aws ec2 create-key-pair --key-name chef | jq .KeyMaterial) | perl -pe 's/"//g' > ~/.ssh/chef.pem
chmod 0600 ~/.ssh/chef.pem

make sure knife[:aws_ssh_key_id] = 'chef' matches --identity-file ~/.ssh/chef.pem 

# install chef/knife

brew cask install chefdk
eval "$(chef shell-init zsh)" # set up gem environment
gem install knife-ec2 knife-windows knife-github-cookbooks

## create chef.io organization 
https://manage.chef.io/organizations/typesafe-scala
download:
  - user key
  - org validation key
  - knife config

## get cookbooks

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


# Select AMI

current: ami-cfa5b68a Windows_Server-2012-R2_R~TM-English-64Bit-Base-2014.12.10

too stripped down (bootstraps in 8 min, though): ami-23a5b666 Windows_Server-2012-R2_RTM-English-64Bit-Core-2014.12.10
userdata.txt: `<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"} & netsh advfirewall firewall set rule group="remote administration" new enable=yes & netsh advfirewall firewall add rule name="WinRM Port" dir=in action=allow protocol=TCP  localport=5985</script>`

older: ami-e9a4b7ac amazon/Windows_Server-2008-SP2-English-64Bit-Base-2014.12.10
userdata.txt: '<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"}</script>'

older: ami-6b34252e Windows_Server-2008-R2_SP1-English-64Bit-Base-2014.11.19
doesn't work: ami-59a8bb1c Windows_Server-2003-R2_SP2-English-64Bit-Base-2014.12.10

# Bootstrap
NOTE: userdata.txt must be one line, no line endings (mac/windows issues?)

```
knife ec2 server create --region us-west-1 --flavor t2.medium -I ami-45332200 -G Windows --user-data userdata.txt --bootstrap-protocol winrm --identity-file ~/.ssh/chef.pem --run-list "scala-jenkins-infra::jenkins-worker-windows"
```

#### during development, don't set name (-N jenkins-worker-windows) to avoid name clashes 


## re-run chef-client on windows
```
knife winrm $IP chef-client -m -P $PASSWORD
```

## set run-list
```
knife node run_list set jenkins-worker-windows jenkins-worker-windows
``` 
## If the bootstrap didn't work at first, complete:
If it appears stuck at "Waiting for remote response before bootstrap.", the userdata didn't make it across 
(check C:\Program Files\Amazon\Ec2ConfigService\Logs) we need to enable unencrypted authentication:

```
aws ec2 get-password-data --instance-id $INST --priv-launch-key ~/.ssh/chef.pem

cord $IP, log in using password above and open a command line:

  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}

knife bootstrap -V windows winrm $IP

```
