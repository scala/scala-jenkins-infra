# Scala's Jenkins Cluster 
The idea is to use chef to configure EC2 instances for both the master and the slaves. The jenkins config will be captured in chef recipes. Everything is versioned, with server and workers not allowed to maintain state.

This is inspired by https://erichelgeson.github.io/blog/2014/05/10/automating-your-automation-federated-jenkins-with-chef/


# Get some tools
```
brew cask install cord
brew install awscli
```

# One-time EC2/IAM setup
## Adding users
Create two users: one for admin ([aws console](https://typesafe-scala.signin.aws.amazon.com/console)) access (generate a password), one for CLI access (using the access key). The `awscli` package provides the `aws` cli, which is used by knife for ec2 provisioning. Add the script user to the `jenkins-knife` group, the console user to the `admin` group.

Once you have your usernames, run `aws configure`. Enter the access key for your `user-scripts` username, set the default region to `us-west-1`. Test by running `aws ec2 describe-instances`.

## Create a script user for use with knife
Never run scripts as root. Best to have a completely separate user.

This user needs the following policy (WIP!):
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:List*",
        "iam:Get*",
        "iam:PassRole",
        "iam:PutRolePolicy"
      ],
      "Resource": "*"
    },
    {
      "Action": "ec2:*",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
```

## Create security group (ec2 firewall)

CONFIGURATOR_IP is the ip of the machine running knife to initiate the bootstrap -- it can be removed once chef-client is running.


```
aws ec2 create-security-group --group-name "Master" --description "Remote access to the Jenkins master" 
aws ec2 authorize-security-group-ingress --group-name "Master" --protocol tcp --port 22 --cidr $CONFIGURATOR_IP/32 # ssh bootstrap
aws ec2 authorize-security-group-ingress --group-name "Master" --protocol tcp --port 8080 --cidr 0.0.0.0/0
```

| Type             | Protocol | Port Range | Source                |
|------------------|----------|------------|-----------------------|
| HTTP             |  TCP     |  80        | 0.0.0.0/0             |
| HTTPS            |  TCP     |  443       | 0.0.0.0/0             |
| Custom TCP Rule  |  TCP     |  8888      | 0.0.0.0/0             |
| All traffic      |  All     |  All       | sg-ecb06389 (Workers) |
| All traffic      |  All     |  All       | sg-1dec3d78 (Windows) |
| SSH              |  TCP     |  22        | $CONFIGURATOR_IP/32   |


```
aws ec2 create-security-group --group-name "Windows" --description "Remote access to Windows instances" 
aws ec2 authorize-security-group-ingress --group-name "Windows" --protocol tcp --port 5985 --cidr $CONFIGURATOR_IP/32 # allow WinRM from the machine that will execute `knife ec2 server create` below
aws ec2 authorize-security-group-ingress --group-name "Windows" --protocol tcp --port 0-65535 --source-group Master
```

| Type             | Protocol | Port Range | Source                |
|------------------|----------|------------|-----------------------|
| All TCP            | TCP | 0 - 65535 |  sg-7afd2d1f (Master) |
| Custom TCP Rule    | TCP | 445       |  $CONFIGURATOR_IP/32  |
| RDP                | TCP | 3389      |  $CONFIGURATOR_IP/32  |
| SSH                | TCP | 22        |  $CONFIGURATOR_IP/32  |
| Custom TCP Rule    | TCP | 5985      |  $CONFIGURATOR_IP/32  |


```
aws ec2 create-security-group --group-name "Workers" --description "Jenkins workers nodes" 
aws ec2 authorize-security-group-ingress --group-name "Workers" --protocol tcp --port 22 --cidr $CONFIGURATOR_IP/32 # ssh bootstrap
aws ec2 authorize-security-group-ingress --group-name "Workers" --protocol tcp --port 0-65535 --source-group Master
```

| Type             | Protocol | Port Range | Source                |
|------------------|----------|------------|-----------------------|
| All TCP     |   TCP    | 0 - 65535  | sg-7afd2d1f (Master) |
| SSH         |   TCP    | 22         | $CONFIGURATOR_IP/32  |


## Instance profiles
This avoids passing credentials for instances to use aws services.

### Create instance profiles
An instance profile must be passed when instance is created. It must contain one role. Can attach more policies to that role at any time.


Based on http://domaintest001.com/aws-iam/

```
aws iam create-instance-profile --instance-profile-name JenkinsMaster
aws iam create-instance-profile --instance-profile-name JenkinsWorkerPublish
aws iam create-instance-profile --instance-profile-name JenkinsWorker

aws iam create-role --role-name jenkins-master         --assume-role-policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/ec2-role-trust-policy.json
aws iam create-role --role-name jenkins-worker         --assume-role-policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/ec2-role-trust-policy.json
aws iam create-role --role-name jenkins-worker-publish --assume-role-policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/ec2-role-trust-policy.json

aws iam add-role-to-instance-profile --instance-profile-name JenkinsMaster        --role-name jenkins-master
aws iam add-role-to-instance-profile --instance-profile-name JenkinsWorker        --role-name jenkins-worker
aws iam add-role-to-instance-profile --instance-profile-name JenkinsWorkerPublish --role-name jenkins-worker-publish
```

### Attach policies to roles:

```
aws iam put-role-policy --role-name jenkins-master --policy-name jenkins-ec2-start-stop --policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/jenkins-ec2-start-stop.json
aws iam put-role-policy --role-name jenkins-master --policy-name jenkins-dynamodb --policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/dynamodb.json

// TODO: once https://github.com/sbt/sbt-s3/issues/14 is fixed, remove s3credentials from nodes and use IAM profile instead
aws iam put-role-policy --role-name jenkins-worker-publish --policy-name jenkins-s3-upload --policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/jenkins-s3-upload.json

aws iam put-role-policy --role-name jenkins-worker --policy-name jenkins-ebs-create-vol --policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/ebs-create-vol.json

aws iam put-role-policy --role-name jenkins-worker-publish --policy-name jenkins-ebs-create-vol --policy-document file:///Users/adriaan/git/scala-jenkins-infra/chef/ebs-create-vol.json
```

NOTE: if you get syntax errors, check the policy doc URL
pass JenkinsWorker as the iam profile to knife bootstrap


## Create an Elastic IP for each node
TODO: attach to elastic IPs 


# Install chef/knife

```
brew cask install chefdk
eval "$(chef shell-init zsh)" # set up gem environment
gem install knife-ec2 knife-windows knife-github-cookbooks chef-vault
```

## Get credentials for the typesafe-scala chef.io organization
Join chef.io (https://manage.chef.io/signup), and ask to be invited to the typesafe-scala org on slack.

For the CLI to work, you need:
```
export CHEF_ORG="typesafe-scala"
```

If your username on chef.io does not match the local username on your machine, you also need
```
export CHEF_USER="[username]"
```

You can then generate and download your private key on https://www.chef.io/account/password. Put it to `.chef/config/$CHEF_USER.pem`, then you can use knife without further config. See `.chef/knife.rb` for key locations.

Test if knife works correctly by running `knife cookbook list`.

Obtain the organization validation key from Adriaan and put it to `.chef/config/$CHEF_ORG-validator.pem`. (Q: When is this key used exactly? https://docs.chef.io/chef_private_keys.html says it's when a new node runs `chef-client` for the first time.)

## Clone scala-jenkins-infra cookbook and its dependencies

I think you can safely ignore `ERROR: IOError: Cannot open or read **/metadata.rb!` in the below

```
cd ~/git/cookbooks
git init .
g commit --allow-empty -m"Initial" 

hub clone scala/scala-jenkins-infra
cd scala-jenkins-infra
ln -sh ~/git/cookbooks .chef/

knife site install cron
knife site install logrotate
knife site install chef_handler
knife site install windows
knife site install chef-client
knife site install aws
knife site install delayed_evaluator
knife site install ebs
knife site install java
knife site install apt
knife site install packagecloud
knife site install runit
knife site install yum
knife site install jenkins
knife site install 7-zip
knife site install ark
knife site install artifactory
knife site install build-essential
knife site install dmg
knife site install yum-epel
knife site install git
knife site install user
knife site install partial_search
knife site install ssh_known_hosts
knife site install git_user
knife site install chef-sbt
knife site install sbt-extras
```

### Switch to unreleased versions from github
```
//fixed: knife cookbook github install opscode-cookbooks/windows    # fix nosuchmethoderror (#150)
//knife cookbook github install adriaanm/jenkins/fix305      # ssl fail on windows -- fix pending: https://github.com/opscode-cookbooks/jenkins/pull/313
knife cookbook github install b-dean/jenkins/http_ca_fixes  # pending fix for above ^^^

knife cookbook github install adriaanm/java/windows-jdk1.6 # jdk 1.6 installer barfs on re-install -- wipe its INSTALLDIR
knife cookbook github install adriaanm/chef-sbt
knife cookbook github install gildegoma/chef-sbt-extras
knife cookbook github install adriaanm/artifactory
```

### Upload cookbooks to chef server
```
knife cookbook upload --all
```

## Cache installers locally
- they are tricky to access, might disappear,...
- checksum is computed with `shasum -a 256`
- TODO: host them on an s3 bucket (credentials are available automatically)


# Configuring the jenkins cluster


## Secure data (one-time setup, can be done before bootstrap)

from http://jtimberman.housepub.org/blog/2013/09/10/managing-secrets-with-chef-vault/

NOTE: the JSON must not have a field "id"!!!

### Chef user with keypair for jenkins cli access
```
eval "$(chef shell-init zsh)" # use chef's ruby, which has the net/ssh gem
ruby chef/keypair.rb > ~/Desktop/chef-secrets/config/keypair.json
ruby chef/keypair.rb > ~/Desktop/chef-secrets/config/scabot-keypair.json

# extract private key to ~/Desktop/chef-secrets/config/scabot.pem

knife vault create master scala-jenkins-keypair \
  --json ~/Desktop/chef-secrets/config/keypair.json \
  --search 'name:jenkins*' \
  --admins adriaan

knife vault create master scabot-keypair \
  --json ~/Desktop/chef-secrets/config/scabot-keypair.json \
  --search 'name:jenkins-master' \
  --admins adriaan

knife vault create master scabot \
  --json ~/Desktop/chef-secrets/config/scabot.json \
  --search 'name:jenkins-master' \
  --admins adriaan

```

### For github oauth

https://github.com/settings/applications/new --> https://github.com/settings/applications/154904
 - Authorization callback URL = https://scala-ci.typesafe.com/securityRealm/finishLogin

```
knife vault create master github-api \
  '{"client-id":"<Client ID>","client-secret":"<Client secret>"}' \
  --search 'name:jenkins-master' \
  --admins adriaan
```

### For nginx ssl

```
knife vault create master scala-ci-key \
  --json scalaci-key.json \
  --search 'name:jenkins-master' \
  --admins adriaan
```


### Workers that need to publish
```
knife vault create worker-publish sonatype \
  '{"user":"XXX","pass":"XXX"}' \
  --search 'name:jenkins-worker-ubuntu-publish' \
  --admins adriaan

knife vault create worker-publish private-repo \
  '{"user":"XXX","pass":"XXX"}' \
  --search 'name:jenkins-worker-ubuntu-publish' \
  --admins adriaan

knife vault create worker-publish s3-downloads \
  '{"user":"XXX","pass":"XXX"}' \
  --search 'name:jenkins-worker-*-publish' \
  --admins adriaan

knife vault create worker-publish chara-keypair \
  --json chara-keypair.json \
  --search 'name:jenkins-worker-ubuntu-publish' \
  --admins adriaan

knife vault create worker-publish gnupg \
  --json /Users/adriaan/Desktop/chef-secrets/gnupg.json \
  --search 'name:jenkins-worker-ubuntu-publish' \
  --admins adriaan

knife vault create worker private-repo-public-jobs \
  '{"user":"XXX","pass":"XXX"}' \
  --search 'name:jenkins-worker-behemoth-*' \
  --admins adriaan

```

#  Dev machine convenience
This is how I set up my desktop to make it easier to connect to the EC2 nodes.
The README assumes you're using this as well.

## /etc/hosts
Note that the IPs are stable by allocating elastic IPs and associating them to nodes.

```
54.67.111.226 jenkins-master
54.67.33.167  jenkins-worker-ubuntu-publish
54.183.156.89 jenkins-worker-windows-publish
54.153.2.9    jenkins-worker-behemoth-1
54.153.1.99   jenkins-worker-behemoth-2
```

## ~/.ssh/config
```
Host jenkins-worker-ubuntu-publish
  IdentityFile ~/Desktop/chef-secrets/config/chef.pem
  User ubuntu

Host jenkins-worker-behemoth-1
  IdentityFile ~/Desktop/chef-secrets/config/chef.pem
  User ec2-user

Host jenkins-worker-behemoth-2
  IdentityFile ~/Desktop/chef-secrets/config/chef.pem
  User ec2-user

Host jenkins-master
  IdentityFile ~/Desktop/chef-secrets/config/chef.pem
  User ec2-user

Host scabot
  HostName jenkins-master
  IdentityFile ~/Desktop/chef-secrets/config/scabot.pem
  User scabot

Host jenkins-worker-windows-publish
  IdentityFile ~/Desktop/chef-secrets/jenkins-chef
  User jenkins
```


# Launch instance on EC2
## Create (ssh) key pair

If your username on AWS does not match the local username on your machine, define
```
export AWS_USER="[username]"
```

```
echo $(aws ec2 create-key-pair --key-name $AWS_USER | jq .KeyMaterial) | perl -pe 's/"//g' > ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
chmod 0600 ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
```

In `knife.rb`, make sure `knife[:aws_ssh_key_id]` points to the pem file.


## Selected AMIs

amazon linux: ami-4b6f650e (Amazon Linux AMI 2014.09.1 x86_64 HVM EBS)
windows:      ami-cfa5b68a (Windows_Server-2012-R2_RTM-English-64Bit-Base-2014.12.10)
ubuntu:       ami-81afbcc4 (Ubuntu utopic 14.10 from https://cloud-images.ubuntu.com/locator/ec2/ for us-west-1/amd64/hvm:ebs-ssd/20141204)


## Bootstrap
NOTE:

  - name is important (used to allow access to vault etc); it can't be changed later, and duplicates aren't allowed (can bite when repeating knife ec2 create)
  - can't access the vault on bootstrap (see After bootstrap below)



```
knife ec2 server create -N jenkins-master \
   --region us-west-1 --flavor t2.small -I ami-4b6f650e \
   -G Master --ssh-user ec2-user \
   --iam-profile JenkinsMaster \
   --identity-file .chef/config/chef.pem \
   --run-list "scala-jenkins-infra::master-init"

knife ec2 server create -N jenkins-worker-windows-publish \
   --flavor c4.xlarge                                     \
   --region us-west-1                                     \
   -I ami-45332200 --user-data chef/userdata/win2012.txt  \
   --iam-profile JenkinsWorkerPublish                     \
   --ebs-optimized --ebs-volume-type gp2                  \
   --security-group-ids sg-1dec3d78                       \
   --subnet subnet-4bb3b80d --associate-eip 54.183.156.89 \
   --server-connect-attribute public_ip_address           \
   --identity-file .chef/config/chef.pem                  \
   --run-list "scala-jenkins-infra::worker-init"


// NOTE: c3.large is much slower than c3.xlarge (scala-release-2.11.x-build takes 2h53min vs 1h40min )
knife ec2 server create -N jenkins-worker-ubuntu-publish  \
   --flavor c4.xlarge                                     \
   --region us-west-1                                     \
   -I ami-81afbcc4 --ssh-user ubuntu                      \
   --iam-profile JenkinsWorker                            \
   --ebs-optimized --ebs-volume-type gp2                  \
   --security-group-ids sg-ecb06389                       \
   --subnet subnet-4bb3b80d --associate-eip 54.67.33.167  \
   --server-connect-attribute public_ip_address           \
   --identity-file .chef/config/chef.pem                  \
   --run-list "scala-jenkins-infra::worker-init"

echo NOTE: Make sure to first remove the ips in $behemothIp from your ~/.ssh/known_hosts. Also remove the corresponding worker from the chef server (can be only one with the same name).
behemothIp=(54.153.2.9 54.153.1.99)
for behemoth in 1 2
do knife ec2 server create -N jenkins-worker-behemoth-$behemoth      \
   --flavor c4.2xlarge                                               \
   --region us-west-1                                                \
   -I ami-4b6f650e --ssh-user ec2-user                               \
   --iam-profile JenkinsWorker                                       \
   --ebs-optimized --ebs-volume-type gp2                             \
   --security-group-ids sg-ecb06389                                  \
   --subnet subnet-4bb3b80d --associate-eip ${behemothIp[$behemoth]} \
   --server-connect-attribute public_ip_address                      \
   --identity-file .chef/config/chef.pem                             \
   --run-list "scala-jenkins-infra::worker-init"
done

```

NOTE: userdata.txt must be one line, no line endings (mac/windows issues?)
`<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"} & netsh advfirewall firewall set rule group="remote administration" new enable=yes & netsh advfirewall firewall add rule name="WinRM Port" dir=in action=allow protocol=TCP  localport=5985</script>`



## After bootstrap (or when nodes are added)

### Update access to vault
```
knife vault update master github-api            --search 'name:jenkins-master'

knife vault update master scala-jenkins-keypair --search 'name:jenkins*'

knife vault update worker private-repo-public-jobs --search 'name:jenkins-worker-behemoth-*'

knife vault update worker-publish s3-downloads  --search 'name:jenkins-worker-*-publish'

knife vault update worker-publish sonatype      --search 'name:jenkins-worker-ubuntu-publish'
knife vault update worker-publish private-repo  --search 'name:jenkins-worker-ubuntu-publish'
knife vault update worker-publish chara-keypair --search 'name:jenkins-worker-ubuntu-publish'
knife vault update worker-publish gnupg         --search 'name:jenkins-worker-ubuntu-publish'
```

### Add run-list items that need the vault
```
knife node run_list set jenkins-master    "scala-jenkins-infra::master-init,scala-jenkins-infra::master-config"

for w in jenkins-worker-windows-publish jenkins-worker-ubuntu-publish jenkins-worker-behemoth-1 jenkins-worker-behemoth-2
  do knife node run_list set $w  "scala-jenkins-infra::worker-init,scala-jenkins-infra::worker-config"
done
```

### Re-run chef manually

- windows:
```
PASS=$(aws ec2 get-password-data --instance-id i-f67c0a35 --priv-launch-key ~/Desktop/chef-secrets/config/chef.pem | jq .PasswordData | xargs echo)
knife winrm jenkins-worker-windows-publish chef-client -m -P $PASS
```

- ubuntu:  `ssh jenkins-worker-ubuntu-publish sudo chef-client`
- amazon linux: `ssh jenkins-worker-behemoth-1`, and then `sudo chef-client`

### Attach eips

```
aws ec2 associate-address --allocation-id eipalloc-df0b13bd --instance-id i-94adaa5e  # jenkins-master
```


# Misc

## "ERROR: null" in slave agent launch log
There are probably multiple instances with the same name on EC2: https://github.com/adriaanm/ec2-start-stop/issues/4
Workaround: make sure EC2 instance names are unique.

## Testing locally using vagrant

http://blog.gravitystorm.co.uk/2013/09/13/using-vagrant-to-test-chef-cookbooks/:

See `.chef/Vagrantfile` -- make sure you first populated `.chef/cookbooks/` using knife,
as [documented above](#get-cookbooks)

## If connections hang
Make sure security group allows access, winrm was enabled using --user-data...

## SSL cert
```
$ openssl genrsa -out scala-ci.key 2048
```
and

```
$ openssl req -new -out scala-ci.csr -key scala-ci.key -config ssl-certs/scalaci.openssl.cnf
```

Send CSR to SSL provider, receive scalaci.csr. Store scala-ci.key securely in vault master scala-ci-key (see above).

Incorporate the cert into an ssl chain for nginx:
```
(cd ssl-certs && cat 00\ -\ scala-ci.crt 01\ -\ COMODORSAOrganizationValidationSecureServerCA.crt 02\ -\ COMODORSAAddTrustCA.crt 03\ -\ AddTrustExternalCARoot.crt > ../files/default/scala-ci.crt)
```

For [forward secrecy](http://axiacore.com/blog/enable-perfect-forward-secrecy-nginx/):
```
openssl dhparam -out files/default/dhparam.pem 2048
```

Confirm values in the csr using:

```
$ openssl req -text -noout -in scala-ci.csr
```

## Retry bootstrap
```
knife bootstrap -c .chef/knife.rb jenkins-worker-ubuntu-publish --ssh-user ubuntu --sudo -c .chef/knife.rb -N jenkins-worker-ubuntu-publish -r "scala-jenkins-infra::worker-init"
```

## WinRM troubles?
If it appears stuck at "Waiting for remote response before bootstrap.", the userdata didn't make it across 
(check C:\Program Files\Amazon\Ec2ConfigService\Logs) we need to enable unencrypted authentication:

```
aws ec2 get-password-data --instance-id $INST --priv-launch-key ~/git/scala-jenkins-infra/.chef/config/chef.pem

cord $IP, log in using password above and open a command line:

  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}

knife bootstrap -V windows winrm $IP
```



## Alternative windows AMIs
too stripped down (bootstraps in 8 min, though): ami-23a5b666 Windows_Server-2012-R2_RTM-English-64Bit-Core-2014.12.10
userdata.txt: `<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"} & netsh advfirewall firewall set rule group="remote administration" new enable=yes & netsh advfirewall firewall add rule name="WinRM Port" dir=in action=allow protocol=TCP  localport=5985</script>`

older: ami-e9a4b7ac amazon/Windows_Server-2008-SP2-English-64Bit-Base-2014.12.10
userdata.txt: '<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"}</script>'

older: ami-6b34252e Windows_Server-2008-R2_SP1-English-64Bit-Base-2014.11.19
doesn't work: ami-59a8bb1c Windows_Server-2003-R2_SP2-English-64Bit-Base-2014.12.10
