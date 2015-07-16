# Maintenance

## Checking status

Pointing your browser to https://manage.chef.io and logging in will
take you to https://manage.chef.io/organizations/typesafe-scala/nodes
which shows node names, IP addresses, uptimes, etc.

It also shows when each node last checked for updated cookbooks ("Last Check-In").

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

2. `knife cookbook upload scala-jenkins-infra`.  This always uploads
   the cookbook to the Typesafe account on chef.io, regardless of
   whether you made changes.

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

Here hostname might be e.g. `jenkins-master` and username could be omitted
to accept the default in your `~/.ssh/config`, or might be e.g. `ec2-user`.

```
ssh username@hostname
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

If you see "pending -- (worker) is offline", try waiting ~5 minutes;
it takes time for ec2-start-stop to spin up workers.

## "ERROR: null" in slave agent launch log
There are probably multiple instances with the same name on EC2: https://github.com/adriaanm/ec2-start-stop/issues/4
Workaround: make sure EC2 instance names are unique.

## Retry bootstrap

```
knife bootstrap -c $PWD/.chef/knife.rb jenkins-worker-ubuntu-publish --ssh-user ubuntu --sudo -c $PWD/.chef/knife.rb -N jenkins-worker-ubuntu-publish -r "scala-jenkins-infra::worker-init"
```

## WinRM troubles?

Normally access to the Windows machines is via ssh, just like
the Linux ones.  If something is so broken you can't get
in that way, use winrm to drop down to graphical access.

If connections hang, Make sure security group allows access, winrm was enabled using --user-data...

If it appears stuck at "Waiting for remote response before bootstrap.", the userdata didn't make it across
(check C:\Program Files\Amazon\Ec2ConfigService\Logs) we need to enable unencrypted authentication:

```
aws ec2 get-password-data --instance-id $INST --priv-launch-key ~/.ssh/typesafe-scala-aws-$AWS_USER.pem

cord $IP, log in using password above and open a command line:

  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}

knife bootstrap -V windows winrm $IP
```
