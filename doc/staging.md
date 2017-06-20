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
knife cookbook site install java
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
knife cookbook site install homebrew
knife cookbook site install nodejs
```

### Current cookbooks

  - apt (6.1.2)
  - ark (2.2.1)
  - artifactory (2.0.0)
  - aws (4.1.3)
  - build-essential (7.0.3)
  - chef-client (7.1.0)
  - chef-vault (1.3.0)
  - chocolatey (1.1.0)
  - compat_resource (12.19.0)
  - cron (3.0.0)
  - delayed_evaluator (0.2.0)
  - dmg (2.2.2)
  - dpkg_autostart (0.2.0)
  - ebs (0.3.6)
  - git (4.2.2)
  - git_user (0.3.1)
  - homebrew (2.1.2)
  - java (1.39.0)
  - jenkins (5.0.2)
  - logrotate (2.1.0)
  - magic_shell (1.0.1)
  - mingw (1.2.5)
  - nodejs (2.4.4)
  - ohai (4.2.3)
  - packagecloud (0.3.0)
  - partial_search (1.0.8)
  - runit (1.7.0)
  - sbt-extras (0.4.0)
  - scala-jenkins-infra (0.6.0)
  - seven_zip (2.0.2)
  - ssh_known_hosts (2.0.0)
  - user (0.4.2)
  - windows (2.1.1)
  - yum-epel (2.1.2)

### Switch to unreleased versions from github

```
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
