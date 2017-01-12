# One-time setup

In contrast to README.md, this document contains instructions that do
not need to be repeated by each new team member.  Everything described
below was already done once and does not normally need to be redone.

(this document is in a rather rough state. for now, it is just
a collection of notes)

# Selected AMIs

  - jenkins-master: ami-3b14f27f (Amazon Linux AMI 2015.03 on HVM Instance Store 64-bit for US West N. California)
  - ubuntu:         ami-2915e16d (search for "vivid hvm:ebs-ssd us-west-1" on https://cloud-images.ubuntu.com/locator/ec2/)
  - windows:        ami-cfa5b68a (Windows_Server-2012-R2_RTM-English-64Bit-Base-2014.12.10)

Eventually we would like to move jenkins-master off Amazon Linux and
onto Ubuntu.

## Alternative windows AMIs

(some old, maybe no longer useful notes)

too stripped down (bootstraps in 8 min, though): ami-23a5b666 Windows_Server-2012-R2_RTM-English-64Bit-Core-2014.12.10
userdata.txt: `<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"} & netsh advfirewall firewall set rule group="remote administration" new enable=yes & netsh advfirewall firewall add rule name="WinRM Port" dir=in action=allow protocol=TCP  localport=5985</script>`

older: ami-e9a4b7ac amazon/Windows_Server-2008-SP2-English-64Bit-Base-2014.12.10
userdata.txt: '<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"}</script>'

older: ami-6b34252e Windows_Server-2008-R2_SP1-English-64Bit-Base-2014.11.19
doesn't work: ami-59a8bb1c Windows_Server-2003-R2_SP2-English-64Bit-Base-2014.12.10

# About ssh keys

when you first bring up an EC2 node, a key is generated.  you can
download the private key once.  that's the AWS_USER thing in the
instructions below. that key always has root access to all nodes

eventually, once everything is running, and assuming your personal
public key has been added to pubkeys.rb, then you won't need your
Amazon-generated key anymore for ssh access, but during genesis,
you'll need it.  during that time, you may want to add this line
to the entries for the various servers in your `~/.ssh/config` file:

    IdentityFile ~/.ssh/typesafe-scala-aws-$AWS_USER.pem

## Create (ssh) key pair

TODO: I don't think the name matters as long as it's used consistently, ultimately your access key and secret credentials are used by aws-cli to generate the keys etc

If your username on AWS does not match the local username on your machine, define
```
export AWS_USER="[username]"
```

Create a keypair and store locally to authenticate with instances over ssh/winrm:
```
echo $(aws ec2 create-key-pair --key-name $AWS_USER | jq .KeyMaterial) | perl -pe 's/"//g' > ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
chmod 0600 ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
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
| Custom TCP Rule  |  TCP     |  node['scabot']['port']      | 0.0.0.0/0             |
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

aws iam create-role --role-name jenkins-master         --assume-role-policy-document file://$PWD/chef/ec2-role-trust-policy.json
aws iam create-role --role-name jenkins-worker         --assume-role-policy-document file://$PWD/chef/ec2-role-trust-policy.json
aws iam create-role --role-name jenkins-worker-publish --assume-role-policy-document file://$PWD/chef/ec2-role-trust-policy.json

aws iam add-role-to-instance-profile --instance-profile-name JenkinsMaster        --role-name jenkins-master
aws iam add-role-to-instance-profile --instance-profile-name JenkinsWorker        --role-name jenkins-worker
aws iam add-role-to-instance-profile --instance-profile-name JenkinsWorkerPublish --role-name jenkins-worker-publish
```

### Attach policies to roles:

NOTE: if you get syntax errors, check the policy doc URL

```
aws iam put-role-policy --role-name jenkins-master --policy-name jenkins-ec2-start-stop        --policy-document file://$PWD/chef/jenkins-ec2-start-stop.json
aws iam put-role-policy --role-name jenkins-master --policy-name jenkins-dynamodb              --policy-document file://$PWD/chef/dynamodb.json
aws iam put-role-policy --role-name jenkins-master --policy-name jenkins-ebs-create-vol        --policy-document file://$PWD/chef/ebs-create-vol.json
```

```
aws iam put-role-policy --role-name jenkins-worker --policy-name jenkins-ebs-create-vol        --policy-document file://$PWD/chef/ebs-create-vol.json
```

TODO: once https://github.com/sbt/sbt-s3/issues/14 is fixed, remove s3credentials from nodes (use IAM profile below instead)
```
aws iam put-role-policy --role-name jenkins-worker-publish --policy-name jenkins-s3-upload      --policy-document file://$PWD/chef/jenkins-s3-upload.json
aws iam put-role-policy --role-name jenkins-worker-publish --policy-name jenkins-ebs-create-vol --policy-document file://$PWD/chef/ebs-create-vol.json
```


## Create an Elastic IP for each node

TODO: attach to elastic IPs


# Configuring the jenkins cluster

## Secure data

can be done before bootstrap

from http://jtimberman.housepub.org/blog/2013/09/10/managing-secrets-with-chef-vault/

NOTE: the JSON must not have a field "id"!!!

## Organization validation key

(not sure where this goes, temporally)

Obtain the organization validation key from Adriaan and put it to `$PWD/.chef/config/$CHEF_ORG-validator.pem`. (Q: When is this key used exactly? https://docs.chef.io/chef_private_keys.html says it's when a new node runs `chef-client` for the first time.)

## Chef user with keypair for jenkins cli access

```
eval "$(chef shell-init zsh)" # use chef's ruby, which has the net/ssh gem
ruby chef/keypair.rb > $PWD/.chef/keypair.json
ruby chef/keypair.rb > $PWD/.chef/scabot-keypair.json

## extract private key to $PWD/.chef/scabot.pem

knife vault create master scala-jenkins-keypair \
  --json $PWD/.chef/keypair.json \
  --search 'name:jenkins*' \
  --admins adriaan

knife vault create master scabot-keypair \
  --json $PWD/.chef/scabot-keypair.json \
  --search 'name:jenkins-master' \
  --admins adriaan

knife vault create master scabot \
  {
    "jenkins": {
      "token": "..."
    },
    "github": {
      "scala":    {"token": "..."}
    }
  }
  --search 'name:jenkins-master' \
  --admins adriaan

```

## For github oauth

https://github.com/organizations/scala/settings/applications --> https://github.com/organizations/scala/settings/applications/154904
 - Authorization callback URL = https://scala-ci.typesafe.com/securityRealm/finishLogin

```
knife vault create master github-api \
  '{"client-id":"<Client ID>","client-secret":"<Client secret>"}' \
  --search 'name:jenkins-master' \
  --admins adriaan
```

## For nginx ssl

```
knife vault create master scala-ci-key \
  --json scalaci-key.json \
  --search 'name:jenkins-master' \
  --admins adriaan
```


## Workers that need to publish
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
  --json $PWD/.chef/config/chara-keypair.json \
  --search 'name:jenkins-worker-ubuntu-publish' \
  --admins adriaan

knife vault create worker-publish gnupg \
  --json   $PWD/.chef/config/gnupg.json \
  --search 'name:jenkins-worker-ubuntu-publish' \
  --admins adriaan

knife vault create worker private-repo-public-jobs \
  '{"user":"XXX","pass":"XXX"}' \
  --search 'name:jenkins-worker-behemoth-*' \
  --admins adriaan

```

# Bootstrap

NOTE:

  - name is important (used to allow access to vault etc); it can't be changed later, and duplicates aren't allowed (can bite when repeating knife ec2 create)
  - can't access the vault on bootstrap (see After bootstrap below)
  - AWS machines have a persistent root partition.



```
   --subnet subnet-4bb3b80d --associate-eip 54.67.111.226 \
   --server-connect-attribute public_ip_address           \

knife ec2 server create -N jenkins-master                  \
   --flavor m3.large                                       \
   --region us-west-1                                      \
   -I ami-3b14f27f                                         \
   -G Master --ssh-user ec2-user                           \
   --iam-profile JenkinsMaster                             \
   --security-group-ids sg-7afd2d1f                        \
   --identity-file ~/.ssh/typesafe-scala-aws-$AWS_USER.pem \
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
   --identity-file ~/.ssh/typesafe-scala-aws-$AWS_USER.pem             \
   --run-list "scala-jenkins-infra::worker-init"


// NOTE: c3.large is much slower than c3.xlarge (scala-release-2.11.x-build takes 2h53min vs 1h40min )

# NOTE: Make sure to first remove the ips in $workerIp from your ~/.ssh/known_hosts.
# Also remove the corresponding worker from the chef server (can be only one with the same name).

workerName=(jenkins-worker-behemoth-1 jenkins-worker-behemoth-2 jenkins-worker-ubuntu-publish)
workerIp=(54.153.2.9 54.153.1.99 54.67.33.167)
workerFlavor=(c4.2xlarge c4.2xlarge c4.xlarge)

for worker in 1 2 3
do knife ec2 server create -N ${workerName[$worker]}             \
   --flavor ${workerFlavor[$worker]}                             \
   --region us-west-1                                            \
   -I ami-81afbcc4 --ssh-user ubuntu                             \
   --hint ec2                                                    \
   --iam-profile JenkinsWorker                                   \
   --ebs-optimized --ebs-volume-type gp2                         \
   --security-group-ids sg-ecb06389                              \
   --subnet subnet-4bb3b80d --associate-eip ${workerIp[$worker]} \
   --server-connect-attribute public_ip_address                  \
   --identity-file ~/.ssh/typesafe-scala-aws-$AWS_USER.pem       \
   --run-list "scala-jenkins-infra::worker-init"
done
```

### NOTES
- `--hint ec2` should enable ec2 detection (so that `node[:ec2]` gets populated by ohai);
  It does the equivalent of `ssh ${workerIp[$worker]} sudo mkdir -p /etc/chef/ohai/hints/ && sudo touch /etc/chef/ohai/hints/ec2.json`

- userdata.txt must be one line, no line endings (mac/windows issues?)
  `<script>winrm quickconfig -q & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"} & netsh advfirewall firewall set rule group="remote administration" new enable=yes & netsh advfirewall firewall add rule name="WinRM Port" dir=in action=allow protocol=TCP  localport=5985</script>`


## After bootstrap

follow the instructions in [adding-nodes.md](adding-nodes.md)


## Additional manual steps

### Scabot access to jenkins

The jenkins token for scabot has to be configured manually:
 - get the API token from https://scala-ci.typesafe.com/user/scala-jenkins/configure
 - use it create `scabot-jenkins.json` as follows
 ```
 {
   "id": "scabot",
   "jenkins": {
     "token": "<TOKEN>"
   }
 }
 ```
 - do `knife vault update master scabot -J scabot-jenkins.json`

## Artifactory

 - Set admin password.
 - create repos (TODO: automate)
 - Create scala-ci user that can push to scala-release-temp and scala-pr-validation-snapshots,
 - coordinate scala-ci credentials with jenkins via
```
knife vault update worker-publish private-repo -J private-repo.json
```

where `private-repo.json`:
```
{
  "id": "private-repo",
  "user": "scala-ci",
  "pass": "???"
}
```

## GitHub webhook

Add a webhook via https://github.com/scala/scala/settings/hooks/new:

 - Payload URL: https://scala-ci.typesafe.com/githoob
 - Content type: application/json
 - Individual events:
   - Issues
   - Pull Request
   - Push
   - Issue comment
   - Pull Request review comment

## Misc notes

### Cache installers locally

- they are tricky to access, might disappear,...
- checksum is computed with `shasum -a 256`
- TODO: host them on an s3 bucket (credentials are available automatically)

# Recreating Jenkins master

see [recreate-jenkins-master.md](recreate-jenkins-master.md)
