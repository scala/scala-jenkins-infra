# Maintenance

(this document is in a rather rough state. for now, it is just
a collection of notes)

## Notes on cookbooks

you do need to clone scala-jenkins-infra
in order to update that one cookbook, even if you never
install or upload the other cookbooks

"Adriaan could also make a tarball of all the other stuff"

## Upload cookbooks to chef server

```
knife cookbook upload --all
```

this has not been done since the initial install!

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
