# Setup

This document has how-to information for new team members wishing to
help maintain the CI infrastructure.

It's assumed you're using Mac OS X.  (We imagine most of the
instructions would work on Linux as well, with minor changes.)

One-time setup instructions for the CI infrastructure _as a whole_
are in a separate document, [genesis.md](genesis.md).


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
Host jenkins-worker-publish
  IdentityFile /Users/adriaan/.ssh/ansible.pem
  User admin

Host jenkins-worker-behemoth-1
  IdentityFile /Users/adriaan/.ssh/ansible.pem
  User admin

Host jenkins-worker-behemoth-2
  IdentityFile /Users/adriaan/.ssh/ansible.pem
  User admin

Host jenkins-worker-behemoth-3
  IdentityFile /Users/adriaan/.ssh/ansible.pem
  User admin

Host jenkins-master
  IdentityFile /Users/adriaan/.ssh/ansible.pem
  User admin

Host scabot
  HostName jenkins-master
  User scabot

Host jenkins-worker-windows-publish
  HostName 172.31.0.178
  IdentityFile ~/.ssh/scala-jenkins.pem
  User jenkins
  ProxyCommand ssh -q -W %h:%p jenkins-master

Host influxdb
  HostName 172.31.0.100
  User ubuntu
  ProxyCommand ssh -q -W %h:%p jenkins-master
```

Verify that you can actually ssh to the various machines.

But note that only master is always up.  You can bring any node up by
launching the associated worker on Jenkins, which uses the
https://github.com/lightbend/ec2-start-stop Jenkins plugin.

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

    sudo su jenkins
    ssh -i ~/.ssh/id_worker_windows jenkins@172.31.0.178

which should get you to a Cygwin prompt.  (If it doesn't work, maybe
you forgot to bring the Windows node online first?)

Keys are stored using ansible vault.

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
