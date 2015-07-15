# Staging using Vagrant

When making small changes to our CI (such as changes to the Jenkins
configs), we often just push them directly into production and test
them there.

For more complex or risky changes, you'll want to test them first in a
local staging environment, using Vagrant.

## Status of these instructions

They may be out of date.  Adriaan has done this; Seth has not.

## Clone scala-jenkins-infra cookbook and its dependencies

I think you can safely ignore `ERROR: IOError: Cannot open or read **/metadata.rb!` in the below

```
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

### About dependencies

Note that we do not have any automatic process for keeping
the cookbook version numbers in this file in sync with
those on our chef server, viewable at
https://manage.chef.io/organizations/typesafe-scala/cookbooks.
Most of the time it probably doesn't matter, since the version
numbers in `install.sh` are used only for testing things locally.

## Testing locally using vagrant

http://blog.gravitystorm.co.uk/2013/09/13/using-vagrant-to-test-chef-cookbooks/:

See `$PWD/.chef/Vagrantfile` -- make sure you first populated `$PWD/.chef/cookbooks/` using knife,
as documented above.
