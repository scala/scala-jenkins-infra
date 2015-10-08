# Maintenance

## Checking status

Pointing your browser to https://manage.chef.io and logging in will
take you to https://manage.chef.io/organizations/typesafe-scala/nodes
which shows node names, IP addresses, uptimes, etc.

It also shows when each node last checked for updated cookbooks ("Last Check-In").

## ssh access

For troubleshooting Jenkins in particular it's often to helpful to ssh
in to the worker nodes and poke around the workspaces, see what
processes are running, that kind of thing.

You can also delete files if we've run out of disk space, though our
first line of defense on this is the "Clear Workspace" button in the
Jenkins UI.

## Updating the scala-jenkins-infra cookbook

Note that the setup instructions don't require you to clone all of the
cookbooks to your local machine, only the scala-jenkins-infra
cookbook.  That's because our own cookbook is the one we usually
update; the rest don't normally need to be touched.

If you change the scala-jenkins-infra cookbook, you don't need
to push your change anywhere in order to test it in production.
We often test changes that way, and then after verifying that
the change is working as desired in production, we push the change
to scala/scala-jenkins-infra.

To make changes,

### 1. Edit the cookbook

Edit the cookbook.  (For example, a common change is to edit
one of the `.xml.erb` files for Jenkins.)

### 2. Upload the cookbook

    knife cookbook upload scala-jenkins-infra

This always uploads the cookbook to the Typesafe account on chef.io,
regardless of whether you made changes.

### 3. Run chef-client

Run `chef-client` on the affected nodes (usually jenkins-master),
which will cause the node to get the updated cookbook from chef.io.
You can run it automatically or manually.

Running it automatically just involves waiting.  On a regular schedule
(every 15 minutes, 30 minutes, something like that? it's configured in
our cookbook for chef-client itself), an already running chef-client
process will wake up and check chef.io for updates.  (The log for
the run presumably goes somewhere, but where? See
https://github.com/scala/scala-jenkins-infra/issues/110.)

But it's usually better to do it manually because you can watch it
happen and catch mistakes.  Any cookbook changes found will show up as
light-gray diffs in the `chef-client` output so you can spot and
sanity-check them.  If diffs are found, the cookbook specifies what
should happen as a result -- for example, that service might be
restarted.

The commands to run chef-client depend on whether the node in question
is Linux or Windows:

#### Linux node

Here `hostname` might be e.g. `jenkins-master` and username can be omitted
to accept the default in your `~/.ssh/config`, or can be explicitly supplied
e.g. `ec2-user@jenkins-master`.

```
ssh hostname   # or username@hostname to override your ~/.ssh/config default
sudo su --login # --login needed on ubuntu to set SSL_CERT_FILE (it's done in /etc/profile.d)
chef-client
```

#### Windows node

```
PASS=$(aws ec2 get-password-data --instance-id i-f67c0a35 --priv-launch-key ~/.ssh/typesafe-scala-aws-$AWS_USER.pem | jq .PasswordData | xargs echo)
knife winrm jenkins-worker-windows-publish chef-client -m -P $PASS
```

# Misc

The remainder of this document is just rough notes.

## Upload all cookbooks to chef server

```
knife cookbook upload --all
```

this has not been done since the initial install!

"Adriaan could also make a tarball" of his all-cookbooks setup
sometime, maybe.

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


# Troubleshooting

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
There are probably multiple instances with the same name on EC2: https://github.com/adriaanm/ec2-start-stop/issues/4
Workaround: make sure EC2 instance names are unique.

## Retry bootstrap

```
knife bootstrap -c $PWD/.chef/knife.rb jenkins-worker-ubuntu-publish --ssh-user ubuntu --sudo -c $PWD/.chef/knife.rb -N jenkins-worker-ubuntu-publish -r "scala-jenkins-infra::worker-init"
```

## Need chara access?

If something in the publishing process that talks to chara.epfl.ch is
failing, you might want to ssh to chara to troubleshoot.  The Linux
publisher node has the necessary ssh private key, so you can do first
ssh to jenkins-worker-ubuntu-publish, then from there do:

     ssh -i /home/jenkins/.ssh/for_chara scalatest@chara.epfl.ch

If you need more access to chara than that, contact Fabien Salvi
at EPFL.

## WinRM troubles?

To verify that you have Windows connectivity:

* make sure `jenkins-worker-windows-publish` is online; you can bring it
  online by logging into Jenkins and pressing the "Launch slave agent"
  button at https://scala-ci.typesafe.com/computer/jenkins-worker-windows-publish/

If connections hang, make sure:

* security group allows access to your IP
    * unless you happen to be at an already-whitelisted location (the Typesafe office in SF, perhaps?) you must specifically whitelist your IP address or a range of IP addresses, in the "Windows" security group in the AWS Console, for incoming access to port 3389 (RDP))
* WinRM was enabled using `--user-data`
* ...?

If it appears stuck at "Waiting for remote response before bootstrap.", the userdata didn't make it across
(check `C:\Program Files\Amazon\Ec2ConfigService\Logs`), so we need to enable unencrypted authentication:

```
aws ec2 get-password-data --instance-id $INST --priv-launch-key ~/.ssh/typesafe-scala-aws-$AWS_USER.pem

cord $IP  # log in using password above, open a command line, and do:

  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}

knife bootstrap -V windows winrm $IP
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
