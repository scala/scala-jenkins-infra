# Maintenance

## ssh access

For troubleshooting Jenkins in particular it's often to helpful to ssh
in to the worker nodes and poke around the workspaces, see what
processes are running, that kind of thing. (See [setup instructions](client-setup.md#hosts-and-ssh-config).)

## Monitoring disk space

We should always have at least 10G or so free on all nodes.  A member
of the Scala team should check the free disk space numbers on all
nodes about every 3 to 4 days.  (Better yet, automate it.  And if
there is a chronic space problem, address the cause.)

A quick way to keep an eye on disk space is by visiting
https://scala-ci.typesafe.com/computer/.  You'll need to launch
any offline nodes in order to get a disk space number.

All of the nodes have a tendency to gradually run out of space, and
it's also possible to have a temporary space issue, e.g. if a
community build is run on a lot of different Scala versions.

Tips for addressing gradually dwindling free space:

* on the publish nodes (windows and ubuntu), the usual culprit is
  `/home/jenkins/tmp`.  ssh in and just blow away everything in there
  (but not while a job is running!).
* on jenkins-master, both the `/` partition and the `/var/lib/jenkins`
  partition are possible concerns.
  * In either partition, the culprit may vary. Poke around with commands like
    `find` and `du` and see where the space is going.  `ncdu -x`
    is useful. (`-x` prevents crossing volume boundaries.)
  * In the root partition,
     - `sudo apt-get clean` should reclaim some space; 
     - sometimes `/var/log/nginx/access.log` grows like crazy when running a lot of community builds. Those can be deleted (or `mv`'d to /var/lib/jenkins where there's more space)
  * Under `/var/lib/jenkins`, if you can't
      find anything else to delete, you can delete some old builds
      (`jobs/*/builds`) that we're unlikely to need to refer to again.
      There are different ways to do this; see e.g.
      [this Stack Overflow question](https://stackoverflow.com/questions/13052390/jenkins-remove-old-builds-with-command-line).
      Example command that worked for me: `curl -u SethTisue:myauthkey -X POST 'https://scala-ci.typesafe.com/job/scala-2.11.x-integrate-community-build/[750-900]/doDelete'` where `SethTisue` is my GitHub user name and `myauthkey` is actually a hex thing I generated [on GitHub](https://github.com/settings/tokens).

Tips for addressing a temporary free-space issue on the behemoths:

* Usually the problem is in `/home/jenkins`.
* A common cause for temporary greatly increased disk usage is closely
  spaced bumping of the community build Scala SHAs, and/or doing
  community build runs with PR snapshot SHAs.
* The easiest way to address it is to clear a community build job's
  workspace.
  * Deleting that many files takes a long time (10+ minutes).
  * Therefore, the "Clear Workspace" button in the Jenkins UI is not the best way to do this,
    since the UI will time out will before the workspace finishes clearing.
  * Instead, stop any community build jobs running on the worker in question,
    then ssh to the worker, `cd` to `/home/jenkins/workspace`, then
    e.g. `mv scala-2.12.x-integrate-community-build trashme`. With the
    old directory moved aside, it's now safe to restart the job.
    But then also, you want to `rm -rf trashme &; disown %`.
    You don't want the node to go down before the `rm` process finishes,
    so make sure you queue up a new job run in Jenkins, that will keep
    the node up.
* From time to time we can delete `~/.dbuild`, `~/.ivy2`, `~/.m2`


# Misc

The remainder of this document is just rough notes.


## SSL cert

We're using letsencrypt certificates, auto-renewing every 90 days.

```
 sudo apt-get install python-certbot-nginx -t stretch-backports
 sudo certbot --nginx
```

The challenge/response happens over http, so I had to open up that port for master.


### static diffie-hellman param
For [forward secrecy](http://axiacore.com/blog/enable-perfect-forward-secrecy-nginx/):
```
openssl dhparam -out files/default/dhparam.pem 1024
```

Using 1024 bits (instead of 2048) for DH to be Java 6 compatible... Bye-bye A+ on https://www.ssllabs.com/ssltest/analyze.html?d=scala-ci.typesafe.com


# Give up, bypass Chef?

When automating something Chef is too painful, we sometimes just make
a change manually.  This has obvious downsides:

* if the node needs to be recreated, we'll lose the manual change
* we could easily lose or forget about the manual change other
  ways, too

As a matter of policy, if you do anything manually, please add
an entry to
https://github.com/scala/scala-jenkins-infra/blob/master/automationPending.md
that explains what you did, when, and why.

# Troubleshooting

## Artifactory offline?

try `sudo systemctl restart artifactory.service` on jenkins-master

lately (April/May 2018) it has been going down pretty regularly.
Adriaan writes, "I think the problem is that when it gets updated
through apt-get, the daemon fails to restart.  I removed the jfrog
source from nano `/etc/apt/apt.conf.d/50unattended-upgrades` so now we
have to manually upgrade it once in a while, but hopefully it will
stay up."

## Worker offline?

From the [list of nodes](https://scala-ci.typesafe.com/computer/),
you can click the entry for the node you're interested in and
from there, use the "Log" action on the left to see if the node
is in the process of coming online, and if so, watch it happen.

It takes a few minutes for ec2-start-stop to spin up a worker.

You can manually bring a node online by pressing the "Launch slave
agent" button.

## Worker goes offline during manual testing?

If you ssh in to a worker to poke around, that won't prevent Jenkins
from taking the worker offline if it is otherwise idle.  This can get
annoying.

The only we way know of to force the node to stay up is, ironically,
to use the node's "Mark this node temporarily offline" button.  This
tells Jenkins not to start any jobs on the node, but it also prevents
the node from being idled.  Don't forget to press "Bring this node
back online" when you're done.

## "ERROR: null" in slave agent launch log
There are probably multiple instances with the same name on EC2: https://github.com/lightbend/ec2-start-stop/issues/4
Workaround: make sure EC2 instance names are unique.


## Need chara access?

If something in the publishing process that talks to chara.epfl.ch is
failing, you might want to ssh to chara to troubleshoot.  The Linux
publisher node has the necessary ssh private key, so you can do first
ssh to jenkins-worker-ubuntu-publish, then from there do:

     ssh -i /home/jenkins/.ssh/jenkins_lightbend_chara scalatest@chara.epfl.ch

If you need more access to chara than that, contact Fabien Salvi
at EPFL.

## WinRM troubles?

You may wish to consult [Amazon's doc on WinRM+EC2](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/connecting_to_windows_instance.html).

To verify that you have Windows connectivity:

* make sure `jenkins-worker-windows-publish` is online; you can bring it
  online by logging into Jenkins and pressing the "Launch slave agent"
  button at https://scala-ci.typesafe.com/computer/jenkins-worker-windows-publish/

If connections hang, make sure:

* security group allows access to your IP
    * unless you happen to be at an already-whitelisted location (the Lightbend office in SF, perhaps?) you must specifically whitelist your IP address or a range of IP addresses, in the "Windows" security group in the AWS Console, for incoming access to port 3389 (RDP))
* WinRM was enabled using `--user-data`
* ...?

If it appears stuck at "Waiting for remote response before bootstrap.", the userdata didn't make it across
(check `C:\Program Files\Amazon\Ec2ConfigService\Logs`), so we need to enable unencrypted authentication:

```
aws ec2 get-password-data --instance-id $INST --priv-launch-key ~/.ssh/typesafe-scala-aws-$AWS_USER.pem

cord $IP  # log in using password above, open a command line, and do:

  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}

```

random CoRD tips:

* right-click is shift-control-click

## Cygwin troubles?

**symptom:** `'\r': command not found`

**solution:**: you're running a shell script that has Windows line endings.
check the script out from version control with `eol=lf`.  (you could
also do `export SHELLOPTS; set -o igncr` to tell bash to ignore
the extra carriage return characters, but it's better to address
the cause.)

**symptom:** stuff is broken

**solution:** it may be worth consulting the various notes in the
comments in [issue #36](https://github.com/scala/scala-jenkins-infra/issues/36),
some of which will probably end up in this doc
