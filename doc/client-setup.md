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

Normally, access to the Windows machines is via ssh, just like the
Linux ones, but you can also use the graphical desktop if you need to.
Details follow.

### Remote access (command line)

Instead of using a key of your own to ssh in like on the Linux nodes,
access is via a shared keypair.  ("Windows sshd is harder to
configure" than on Linux, comments Adriaan.)

If you want to be able to ssh to a Windows node, you need to get the
keypair onto your own machine.  (Footnote: You might think to ssh to
jenkins-master and then to Windows from there, but that won't work
because jenkins-master doesn't have the key on disk; rather, it's
passed directly to Jenkins via `node.run_state`.)

The keypair is stored in our Chef vault (as provided by the chef-vault
cookbook) as `scala-jenkins-keypair`.  To get it into your `~/.ssh`
directory, do:

    knife vault show --format json master scala-jenkins-keypair \
      | jq -r .private_key > ~/.ssh/jenkins_id_rsa
    knife vault show --format json master scala-jenkins-keypair \
      | jq -r .public_key  > ~/.ssh/jenkins_id_rsa.pub

(If you get "master/scala-jenkins-keypair is not encrypted with your
public key", that means you must ask one of the existing vault admins
to do e.g.

    knife vault update master scala-jenkins-keypair \
      -A adriaan,tisue,lrytz \
      --search 'name:jenkins-master

with your own Chef name alongside the other scoundrels on the second line.)

Now you can:

    ssh -i ~/.ssh/jenkins_id_rsa jenkins-worker-windows-publish

and get to a Cygwin prompt.

### Remote access (graphical)

If something is so broken you can't get in that way, use
WinRM (Windows Remote Management) to drop down to graphical access.
[CoRD](http://cord.sourceforge.net) "is a Mac OS X remote desktop
client for Microsoft Windows computers" that speaks WinRM.  You can
install it with [Homebrew Cask](http://caskroom.io):

```
brew cask install cord
```

There is some advice on setting up and troubleshooting Windows
connections in the "Maintenance" section of this documentation.
