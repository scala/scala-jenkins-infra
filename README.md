# Scala CI overview

Our Jenkins-based CI infrastructure serves multiple purposes.  We
use it to:

* (automatically) validate pull requests
* (automatically) run the community build
* (automatically) build nightly releases
* (manually) run scripts at release time (to build installers,
  update scala-lang.org, and so on)

All of these are described in greater detail below.

## A note on Travis-CI

Many of the smaller repos under the scala organization
(for example, [scala-xml](https://github.com/scala/scala-xml))
use [Travis-CI](http://travis-ci.org) for continuous integration.
Travis requires the least setup or administration, so it's the easiest
way for maintainers from the open-source community to participate.
The Travis configs (in `.travis.yml` files in each
repository root) are generally self-contained and straightforward.

But for the [main Scala repository](https://github.com/scala/scala)
itself, we have found that we want the full power of Jenkins: for
capacity, for performance, and for full control over every aspect of
the builds.  Also, we want to build every commit, not just every push.

(We do, however, try to design our Jenkins configurations to be
consistent, within reason, with a possible eventual move to Travis.)

The rest of this document describes Jenkins only.

## Old vs. new infrastructure

There is an old Jenkins setup at EPFL, running on physical servers in
the basement in Lausanne and administered by Antonio Cunei.  We would
like to retire the old setup eventually, but not everything has been
migrated to the new infrastructure yet.

The old stuff lives at:

 * https://jenkins-dbuild.typesafe.com:8499 (dbuild-based community build)
 * https://scala-webapps.epfl.ch/jenkins/ (other jobs)

And associated GitHub repos include:

 * https://github.com/scala/jenkins-config
 * https://github.com/scala/jenkins-scripts

If you want an admin login to the old Jenkins, ask Antonio to add
you to the LDAP user database on http://moxie.typesafe.com
(another server in the same basement).  It's normally sufficient
to interact with Jenkins using its web UI; you shouldn't normally
need actual ssh access to the servers, but that's available
from Antonio as well if needed.

The old stuff is not documented in detail here, on the assumption that
its continued existence is temporary.  Adriaan's rough plan for
migration is here: https://gist.github.com/adriaanm/407b451ebcd1f3b698e4

The remainder of this document covers the new infrastructure only.

## New infrastructure

The new Jenkins infrastructure runs on virtual servers hosted by
Amazon.  The virtual servers are created and configured automatically
via Chef.  Everything is scripted and the scripts version-controlled
so the servers can automatically be rebuilt at anytime.  It's all
described and documented in the
[scala-jenkins-infra repo](https://github.com/scala/scala-jenkins-infra).

### Pull requestion validation

Every commit in a pull request (not just the last!) must pass a series
of checks before the PR's "build status" becomes green:

* `cla` -- verify that the submitter of the PR has digitally signed
  the Scala CLA using their GitHub identity.  (Handled by Scabot,
  not Jenkins.)
* `validate-main` -- top-level Jenkins job.
  Does no work of its own, just orchestrates the other jobs
  as follows: runs `validate-publish-core` first, and if it succeeds,
  then runs `validate-test` and `integrate-ide` in parallel.
* `validate-publish-core` -- build Scala and publish artifacts via
  Artifactory on scala-ci. The resulting artifacts are used during the
  remaining stages of validation.  The artifacts can also be used for
  manual testing; instructions for adding the right resolver and
  setting `scalaVersion` appropriately are in the
  [Scala repo README](https://github.com/scala/scala/blob/2.11.x/README.md).
* `validate-test` -- run the Scala test suite
* `integrate-ide` -- run the ScalaIDE test suite

In the future, we plan to make the [Scala community build]
(https://github.com/scala/community-builds) part of PR validation
as well.

PR validation is orchestrated by Scabot, as documented in the
[scabot repo](https://github.com/scala/scabot).  In short, Scabot
listens to GitHub and Jenkins, starts `validate-main` jobs on Jenkins
when appropriate, and updates PRs' build statuses.

Scabot does not talk to our old Jenkins infrastructure, only the
new stuff.

### Naming

The Jenkins job names always correspond exactly with the names of the
scripts in the repo, uniformly across orgs (e.g. scala vs. lampepfl)
and branches.  So for example, validate-test is the name of a job conceptually,
scala-2.11.x-validate-test is the Jenkins name for the job running on
2.11.x in the scala org (since we can't make "virtual" jobs in jenkins
that group by parameter, otherwise we wouldn't need this name
mangling), and the actual script that is run is
https://github.com/scala/scala/blob/2.11.x/scripts/jobs/validate/test.

Exception: "main" jobs are always
[Flow DSL](https://wiki.jenkins-ci.org/display/JENKINS/Build+Flow+Plugin)
meta-jobs with no associated script.

In the job names, `validate` means the job operates on only one repo;
`integrate` means it brings multiple projects/repos together.

### Community build

The community build uses a tool we developed called
[dbuild](https://github.com/typesafehub/dbuild).  It is open-source,
but may not actually have any users outside Typesafe/EPFL.

The dbuild configuration files that specify the Scala community
build live in https://github.com/scala/community-builds.

### Nightly releases

A suite of Jenkins configs with `-release-` in the name uses
the scala/scala and scala/scala-idst repos to make nightly
releases, including installers and Scaladoc, and makes them available
from http://www.scala-lang.org/files/archive/nightly/
and http://www.scala-lang.org/api/nightly/.

(In the scripts that handle this, `chara` refers to the server that
hosts scala-lang.org.)

### "Real" releases

Some of the Jenkins configs relate to building "real" (non-nightly)
Scala releases and are manually, not automatically, triggered,
using Jenkins' "Build with parameters" feature:

 * scala-2.11.x-release-website-update-current
 * scala-2.11.x-release-website-update-api

# Technical details

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

You can then generate and download your private key on https://www.chef.io/account/password. Put it to `$PWD/.chef/config/$CHEF_USER.pem`, then you can use knife without further config. See `$PWD/.chef/knife.rb` for key locations.

Test if knife works correctly by running `knife cookbook list`.

Obtain the organization validation key from Adriaan and put it to `$PWD/.chef/config/$CHEF_ORG-validator.pem`. (Q: When is this key used exactly? https://docs.chef.io/chef_private_keys.html says it's when a new node runs `chef-client` for the first time.)

## Clone scala-jenkins-infra cookbook and its dependencies

I think you can safely ignore `ERROR: IOError: Cannot open or read **/metadata.rb!` in the below

```
cd ~/git/cookbooks
git init .
g commit --allow-empty -m"Initial"

hub clone scala/scala-jenkins-infra
cd scala-jenkins-infra
ln -sh ~/git/cookbooks $PWD/.chef/

knife cookbook site install cron
knife cookbook site install logrotate
knife cookbook site install chef_handler
knife cookbook site install windows
knife cookbook site install chef-client
knife cookbook site install aws
knife cookbook site install delayed_evaluator
knife cookbook site install ebs
knife cookbook site install apt
knife cookbook site install packagecloud
knife cookbook site install runit
knife cookbook site install yum
knife cookbook site install 7-zip
knife cookbook site install ark
knife cookbook site install artifactory
knife cookbook site install build-essential
knife cookbook site install dmg
knife cookbook site install yum-epel
knife cookbook site install git
knife cookbook site install user
knife cookbook site install partial_search
knife cookbook site install ssh_known_hosts
knife cookbook site install git_user

knife cookbook site install chef-vault
```

### Current cookbooks
 - 7-zip               ==  1.0.2
 - apt                 ==  2.7.0
 - ark                 ==  0.9.0
 - artifactory         ==  0.1.1
 - aws                 ==  2.7.0
 - build-essential     ==  2.2.3
 - chef-client         ==  4.3.0
 - chef_handler        ==  1.1.6
 - cron                ==  1.6.1
 - delayed_evaluator   ==  0.2.0
 - dmg                 ==  2.2.2
 - ebs                 ==  0.3.6
 - git                 ==  4.2.2
 - git_user            ==  0.3.1
 - logrotate           ==  1.9.1
 - packagecloud        ==  0.0.17
 - partial_search      ==  1.0.8
 - runit               ==  1.6.0
 - sbt                 ==  0.1.0
 - sbt-extras          ==  0.4.0
 - ssh_known_hosts     ==  2.0.0
 - user                ==  0.4.2
 - windows             ==  1.36.6
 - yum                 ==  3.6.0
 - yum-epel            ==  0.6.0

### Switch to unreleased versions from github
```
knife cookbook github install adriaanm/jenkins/fix305  # custom fixes + https://github.com/opscode-cookbooks/jenkins/pull/313 (b-dean/jenkins/http_ca_fixes)
knife cookbook github install adriaanm/java/windows-jdk1.6  # jdk 1.6 installer barfs on re-install -- wipe its INSTALLDIR
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
ruby chef/keypair.rb > $PWD/.chef/keypair.json
ruby chef/keypair.rb > $PWD/.chef/scabot-keypair.json

# extract private key to $PWD/.chef/scabot.pem

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
      "lampepfl": {"token": "..."}
    }
  }
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
  IdentityFile ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
  User ubuntu

Host jenkins-worker-behemoth-1
  IdentityFile ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
  User ec2-user

Host jenkins-worker-behemoth-2
  IdentityFile ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
  User ec2-user

Host jenkins-master
  IdentityFile ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
  User ec2-user

Host scabot
  HostName jenkins-master
  IdentityFile $PWD/.chef/scabot.pem
  User scabot

Host jenkins-worker-windows-publish
  IdentityFile ~/.ssh/typesafe-scala-aws-$AWS_USER.pem
  User jenkins
```


# Launch instance on EC2
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

## Selected AMIs

  - jenkins-master: ami-3b14f27f (Amazon Linux AMI 2015.03 on HVM Instance Store 64-bit for US West N. California)
  - windows:        ami-cfa5b68a (Windows_Server-2012-R2_RTM-English-64Bit-Base-2014.12.10)
  - ubuntu:         ami-2915e16d (search for "vivid hvm:ebs-ssd us-west-1" on https://cloud-images.ubuntu.com/locator/ec2/)


## Bootstrap
NOTE:

  - name is important (used to allow access to vault etc); it can't be changed later, and duplicates aren't allowed (can bite when repeating knife ec2 create)
  - can't access the vault on bootstrap (see After bootstrap below)



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
knife node run_list set jenkins-master  "recipe[chef-vault],scala-jenkins-infra::master-init,scala-jenkins-infra::master-config,scala-jenkins-infra::master-jenkins,scala-jenkins-infra::master-scabot"

for w in jenkins-worker-windows-publish jenkins-worker-ubuntu-publish jenkins-worker-behemoth-1 jenkins-worker-behemoth-2
  do knife node run_list set $w  "recipe[chef-vault],scala-jenkins-infra::worker-init,scala-jenkins-infra::worker-config"
done
```

### Re-run chef manually

- windows:
```
PASS=$(aws ec2 get-password-data --instance-id i-f67c0a35 --priv-launch-key ~/.ssh/typesafe-scala-aws-$AWS_USER.pem | jq .PasswordData | xargs echo)
knife winrm jenkins-worker-windows-publish chef-client -m -P $PASS
```

- linux
```
ssh jenkins-worker-ubuntu-publish
sudo su --login # --login needed on ubuntu to set SSL_CERT_FILE (it's done in /etc/profile.d)
chef-client
```

### Attach eips

```
aws ec2 associate-address --allocation-id eipalloc-df0b13bd --instance-id i-94adaa5e  # jenkins-master
```

# Example of bringing up a new version of our beloved behemoths
- delete slave in jenkins: https://scala-ci.typesafe.com/computer/jenkins-worker-behemoth-1/delete
- rename EC2 instance in EC2 console (suffix with -old)
- disassociate its EIP (54.153.2.9)
- delete node from manage.chef.io (we only have 5 max)
- remove jenkins-worker-behemoth-1 entry from ~/.ssh/known_hosts
- bootstrap:
```
$ knife ec2 server create -N jenkins-worker-behemoth-1        \
>    --flavor c4.2xlarge                                      \
>    --region us-west-1                                       \
>    -I ami-81afbcc4 --ssh-user ubuntu                        \
>    --iam-profile JenkinsWorker                              \
>    --ebs-optimized --ebs-volume-type gp2                    \
>    --security-group-ids sg-ecb06389                         \
>    --subnet subnet-4bb3b80d --associate-eip 54.153.2.9     \
>    --server-connect-attribute public_ip_address             \
>    --identity-file ~/.ssh/typesafe-scala-aws-$AWS_USER.pem  \
>    --run-list "scala-jenkins-infra::worker-init"
```

- knife vault update master scala-jenkins-keypair --search 'name:jenkins-worker-behemoth-1'
- knife vault update worker private-repo-public-jobs --search 'name:jenkins-worker-behemoth-1'
- knife node run_list set jenkins-worker-behemoth-1  "recipe[chef-vault],scala-jenkins-infra::worker-init,scala-jenkins-infra::worker-config"

- mate ~/.ssh/config
```
Host jenkins-worker-behemoth-1
  IdentityFile /Users/adriaan/.ssh/typesafe-scala-aws-adriaan-scripts.pem
  User ubuntu
```

- ssh jenkins-worker-behemoth-1 and sudo su
```
$ mkdir -p /etc/chef/ohai/hints/
$ touch /etc/chef/ohai/hints/ec2.json
$ chef-client
```

- ssh-jenkins master, sudo and run chef-client to add back the deleted worker

# MANUAL STEPS
## Scabot access to jenkins
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

# Artifactory
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


# Misc

## Worker offline?

If you see "pending -- (worker) is offline", try waiting ~5 minutes;
it takes time for ec2-start-stop to spin up workers.

## "ERROR: null" in slave agent launch log
There are probably multiple instances with the same name on EC2: https://github.com/adriaanm/ec2-start-stop/issues/4
Workaround: make sure EC2 instance names are unique.

## Testing locally using vagrant

http://blog.gravitystorm.co.uk/2013/09/13/using-vagrant-to-test-chef-cookbooks/:

See `$PWD/.chef/Vagrantfile` -- make sure you first populated `$PWD/.chef/cookbooks/` using knife,
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
openssl dhparam -out files/default/dhparam.pem 1024
```

Using 1024 bits (instead of 2048) for DH to be Java 6 compatible... Bye-bye A+ on https://www.ssllabs.com/ssltest/analyze.html?d=scala-ci.typesafe.com

Confirm values in the csr using:

```
$ openssl req -text -noout -in scala-ci.csr
```

## Retry bootstrap
```
knife bootstrap -c $PWD/.chef/knife.rb jenkins-worker-ubuntu-publish --ssh-user ubuntu --sudo -c $PWD/.chef/knife.rb -N jenkins-worker-ubuntu-publish -r "scala-jenkins-infra::worker-init"
```

## WinRM troubles?
If it appears stuck at "Waiting for remote response before bootstrap.", the userdata didn't make it across
(check C:\Program Files\Amazon\Ec2ConfigService\Logs) we need to enable unencrypted authentication:

```
aws ec2 get-password-data --instance-id $INST --priv-launch-key ~/.ssh/typesafe-scala-aws-$AWS_USER.pem

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
