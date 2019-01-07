# One-time setup

In contrast to README.md, this document contains instructions that do
not need to be repeated by each new team member.  Everything described
below was already done once and does not normally need to be redone.

(this document is in a rather rough state. for now, it is just
a collection of notes)

# Selected AMIs

  - linux:   ami-6d03030d (Debian Stretch) --> https://wiki.debian.org/Cloud/AmazonEC2Image/Stretch
  - windows: ami-76227116 (source: amazon/Windows_Server-2012-R2_RTM-English-64Bit-Base-2017.01.11)

(Don't bother automating too much on windows. We could drop it and use our appveyor setup exclusively.)

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

Create two users: one for admin ([aws console](https://typesafe-scala.signin.aws.amazon.com/console)) access (generate a password), one for CLI access (using the access key).

Once you have your usernames, run `aws configure`. Enter the access key for your `user-scripts` username, set the default region to `us-west-1`. Test by running `aws ec2 describe-instances`.


## Create security group (ec2 firewall)

CONFIGURATOR_IP is the ip of the machine running ansible to initiate the bootstrap (TODO is this still true?)


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

```
aws iam put-role-policy --role-name jenkins-worker-publish --policy-name s3-upload-scala      --policy-document file://$PWD/chef/s3-upload-scala.json
aws iam put-role-policy --role-name jenkins-worker-publish --policy-name jenkins-ebs-create-vol --policy-document file://$PWD/chef/ebs-create-vol.json
```

s3-upload-scala.json
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::downloads.typesafe.com.s3.amazonaws.com/scala/*"
        }
    ]
}
```

ebs-create-vol.json:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:CreateVolume",
                "ec2:ModifyVolumeAttribute",
                "ec2:DescribeVolumeAttribute",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:EnableVolumeIO"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

## Create an Elastic IP for each node

TODO: attach to elastic IPs


# Configuring the jenkins cluster


## For github oauth

https://github.com/organizations/scala/settings/applications --> https://github.com/organizations/scala/settings/applications/154904
 - Authorization callback URL = https://scala-ci.typesafe.com/securityRealm/finishLogin

```
  '{"client-id":"<Client ID>","client-secret":"<Client secret>"}'
```


# Bootstrap

This uses ansible, see notes in site.yml.

## After bootstrap

follow the instructions in [adding-nodes.md](adding-nodes.md)


## Additional manual steps

### Scabot access to jenkins

The jenkins token for scabot has to be configured manually:
 - get the API token from https://scala-ci.typesafe.com/user/scala-jenkins/configure
 - encrypt it and store it as scala_jenkins_token in roles/scabot/vars/main.yml


## Artifactory

 - Set admin password.
 - create repos (TODO: automate)
 - Create scala-ci user that can push to scala-integration and scala-pr-validation-snapshots,
 - coordinate scala-ci credentials with jenkins via `repos_private_pass`

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
