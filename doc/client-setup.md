# Setup

This document has how-to information for new team members wishing to
help maintain the CI infrastructure.

It's assumed you're using Mac OS X.  (We imagine most of the
instructions would work on Linux as well, with minor changes.)

One-time setup instructions for the CI infrastructure _as a whole_
are in a separate document, [genesis.md](genesis.md).

## Install chef and knife clients

```
brew cask install chefdk
eval "$(chef shell-init zsh)" # set up gem environment
gem install knife-ec2 knife-windows knife-github-cookbooks chef-vault
```

tips/troubleshooting:

* you might choose to `gem install --user-install` instead so only your
  own `~/.gem` directory is affected (and so you don't need `sudo`)
* if you're on Mac OS X 10.11, make sure you are using ChefDK 0.8.0
  or higher, so as not to run afoul of
  https://github.com/chef/chef-dk/issues/419
* if `gem install` gives an error message about unsatisfiable
  constraints on the version of the chef-config gem, add `-f`
  to force-ignore the problem `¯\_(ツ)_/¯` and cross your fingers
  that nothing goes wrong as a result

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

You can then generate and download your private key on https://manage.chef.io/organizations/typesafe-scala/users. Put it in `~/git/cookbooks/scala-jenkins-infra/.chef/config/$CHEF_USER.pem`. Then you can use knife without further config. See `.chef/knife.rb` for key locations.

Test if knife works correctly by running `knife cookbook list`.

## Hosts and SSH config

To make it easier to connect to the EC2 nodes, perform the following
steps.  They aren't strictly necessary, but the rest of this document
assumes them.

### /etc/hosts

Add the following to your /etc/hosts file:

```
54.67.111.226 jenkins-master
54.67.33.167  jenkins-worker-publish
54.153.2.9    jenkins-worker-behemoth-1
54.153.1.99   jenkins-worker-behemoth-2
54.183.156.89 jenkins-worker-behemoth-3

```

Note that the IPs are stable, by allocating elastic IPs and associating them to nodes.

(The list doesn't include jenkins-worker-windows-publish because
it's only ssh-able from jenkins-master itself; see below.)

### SSH configuration

Add the following to your `~/.ssh/config`:

```
Host jenkins-master
  User admin

Host jenkins-worker-behemoth-1
  User ubuntu

Host jenkins-worker-behemoth-2
  User ubuntu

Host jenkins-worker-ubuntu-publish
  User ubuntu

Host scabot
  HostName jenkins-master
  IdentityFile $PWD/.chef/scabot.pem
  User scabot
```

Verify that you can actually ssh to the various machines.

But note that only master is always up.  You can bring any node up by
launching the associated worker on Jenkins, which uses the
https://github.com/typesafehub/ec2-start-stop Jenkins plugin.

## AWS setup

For many tasks, it's sufficient to have access to Jenkins and Chef
and ssh access to the nodes.

To do some kinds of administration, or to remotely control the
desktop of a Windows node (see "Windows setup" below), you'll
need an AWS account.

### Install AWS client

To talk to AWS instances, you'll need to:

```
brew install awscli
```

[awscli](https://aws.amazon.com/cli/) is the command-line interface
for AWS, consisting of a single command called `aws`.

Next, you'll need a PGP public key.  If you want, an easy way to get
one is to use keybase.io to create it.  (Have an existing member (such
as Adriaan) send you a keybase invite, so you don't have to wait in
the queue for an account.)

Send Adriaan your public key (e.g. by sending him a URL such as
https://keybase.io/sethtisue, or by sending him the actual key
which normally begins: `-----BEGIN PGP PUBLIC KEY BLOCK-----`).
He will use it to encrypt your credentials.

### Get an AWS account

Ask Adriaan to make an account for you, under the typesafe-scala
account.  (Another person who can help with this is Ed Callahan.)
Verify that you are able to
[log in to the AWS Console](https://typesafe-scala.signin.aws.amazon.com/console).

## Windows setup

For most infrastructure work, you'll be dealing primarily with our
Linux instances, but Windows is also part of our infrastructure.  For
example, we build our Windows release bundles on a virtual Windows box
(`jenkins-worker-windows-publish`).  It can also be helpful to have
access to a virtual Windows instance to test Windows-specific changes
to Scala.

The Windows node is accessible via ssh from jenkins-master.  You can
also use the graphical desktop if you need to (e.g. to run a GUI
installer).  Details on both of these options follow.

### Remote access (command line)

Instead of using a key of your own to ssh in like on the Linux nodes,
access is via a shared keypair.  ("Windows sshd is harder to
configure" than on Linux, comments Adriaan.)

You can't ssh directly to the Windows node, but you can get there by
ssh'ing to jenkins-master first.  From jenkins-master, do:

    ssh -i ~/.ssh/jenkins_id_rsa jenkins@172.31.0.178

which should get you to a Cygwin prompt.  (If it doesn't work, maybe
you forgot to bring the Windows node online first?)

Missing key?  If you find that `~/.ssh/jenkins_id_rsa` isn't
present on jenkins-master, you can recreate it as follows.
The keypair is stored in our Chef vault (as provided by the chef-vault
cookbook) as `scala-jenkins-keypair`.  Here's how to retrieve it:

    knife vault show --format json master scala-jenkins-keypair \
      | jq -r .private_key > jenkins_id_rsa
    knife vault show --format json master scala-jenkins-keypair \
      | jq -r .public_key  > jenkins_id_rsa.pub

From there, you can `scp` it up to `~/.ssh` on jenkins-master.

If you get "master/scala-jenkins-keypair is not encrypted with your
public key", that means you must ask one of the existing vault admins
to do e.g.

    knife vault update master scala-jenkins-keypair \
      -A adriaan,tisue,lrytz \
      --search 'name:jenkins-master

### Remote access (graphical)

If something is so broken you can't get in that way,
or if you need to run some GUI thing like an installer, use
WinRM (Windows Remote Management) to drop down to graphical access.
[CoRD](http://cord.sourceforge.net) "is a Mac OS X remote desktop
client for Microsoft Windows computers" that speaks WinRM.  You can
install it with [Homebrew Cask](http://caskroom.io):

```
brew cask install cord
```

There is some advice on setting up and troubleshooting Windows
connections in the "Maintenance" section of this documentation.
