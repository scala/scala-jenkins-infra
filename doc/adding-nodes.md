# Adding nodes

follow these steps:

* during genesis, after bootstrap
* later, whenever nodes are added, or if you want to take
  a worker offline and upgrade it

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

see maintenance.md for instructions

### Attach eips

```
aws ec2 associate-address --allocation-id eipalloc-df0b13bd --instance-id i-94adaa5e  # jenkins-master
```

### Example of bringing up a new version of our beloved behemoths
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

