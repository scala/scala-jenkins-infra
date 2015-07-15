# Setup

This document has how-to information for new team members wishing to
help maintain the CI infrastructure.

It's assumed you're using Mac OS X.  (We imagine most of the
instructions would work on Linux as well, with minor changes.)

One-time setup instructions for the CI infrastructure _as a whole_
are in a separate document, [genesis.md](genesis.md).

## Prerequisites

You'll need to install these tools locally:

```
brew install awscli
brew cask install cord
```

[awscli](https://aws.amazon.com/cli/) is the command-line interface
for AWS, consisting of a single command called `aws`, used throughout
these instructions.

[CoRD](http://cord.sourceforge.net) "is a Mac OS X remote desktop client for Microsoft Windows computers".
This is relevant because `jenkins-worker-windows-publish` builds
Windows release bundles on Windows, so we need virtual Windows
machines to do that on.

plus for Chef and Knife, additionally install:

```
brew cask install chefdk
eval "$(chef shell-init zsh)" # set up gem environment
gem install knife-ec2 knife-windows knife-github-cookbooks chef-vault
```

## Get credentials for the typesafe-scala chef.io organization

Join chef.io (https://manage.chef.io/signup), and ask on Slack to be invited to the typesafe-scala org.

For the CLI to work, you need:
```
export CHEF_ORG="typesafe-scala"
```

If your username on chef.io does not match the local username on your machine, you also need
```
export CHEF_USER="[username]"
```

## Get your public key added

Open a pull request, modeled on https://github.com/scala/scala-jenkins-infra/pull/106,
to add your own ssh public key (not an Amazon-provided key; a personal key of your
own) to `attributes/pubkeys.rb`, so you can use your key to ssh to the various servers.

## Set up directories

```
mkdir -p ~/git/cookbooks
cd ~/git/cookbooks
git init .
git commit --allow-empty -m "Initial"
git config core.autocrlf false
hub clone scala/scala-jenkins-infra
cd scala-jenkins-infra
ln -sh ~/git/cookbooks $PWD/.chef/
mkdir .chef/config
```

(The `core.autocrlf` thing may be needed to prevent "fatal: CRLF would be replaced by LF" errors when cloning cookbook repos, depending on your global git config.)

You can then generate and download your private key on https://www.chef.io/account/password. Put it in `~/git/cookbooks/scala-jenkins-infra/.chef/config/$CHEF_USER.pem`. Then you can use knife without further config. See `.chef/knife.rb` for key locations.

Test if knife works correctly by running `knife cookbook list`.

(this step may not be necessary?) Obtain the organization validation key from Adriaan and put it to `$PWD/.chef/config/$CHEF_ORG-validator.pem`. (Q: When is this key used exactly? https://docs.chef.io/chef_private_keys.html says it's when a new node runs `chef-client` for the first time.)

## Hosts and SSH config

To make it easier to connect to the EC2 nodes, perform the following
steps.  They aren't strictly necessary, but the rest of this document
assumes them.

### /etc/hosts

Add the following to your /etc/hosts file:

```
54.67.111.226 jenkins-master
54.67.33.167  jenkins-worker-ubuntu-publish
54.183.156.89 jenkins-worker-windows-publish
54.153.2.9    jenkins-worker-behemoth-1
54.153.1.99   jenkins-worker-behemoth-2
```

Note that the IPs are stable, by allocating elastic IPs and associating them to nodes.

### SSH configuration

Add the following to your `~/.ssh/config`:

```
Host jenkins-master
  User ec2-user

Host jenkins-worker-behemoth-1
  User jenkins

Host jenkins-worker-behemoth-2
  User jenkins

Host jenkins-worker-ubuntu-publish
  User jenkins

Host jenkins-worker-windows-publish
  User jenkins

Host scabot
  HostName jenkins-master
  IdentityFile $PWD/.chef/scabot.pem
  User scabot
```

Verify that you can actually ssh to the various machines.

But note that only master is always up.  You can bring any node up by
launching the associated worker on Jenkins, which uses the
https://github.com/typesafehub/ec2-start-stop Jenkins plugin.
