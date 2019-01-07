# Manual steps pending automation
Where we list manual interventions on our infra, and ideally how to automate them in the future.

## New pubring.gpg
To try to resolve the tailure to gpg sign the deployment in https://scala-ci.typesafe.com/job/scala-2.11.x-integrate-bootstrap/1126/consoleText,
I noticed that our key had expired on jenkins-worker-ubuntu-publish:

```
jenkins@ip-172-31-15-209:/home/ubuntu$ gpg --list-keys
/home/jenkins/.gnupg/pubring.gpg
--------------------------------
pub   2048R/B41F2BCE 2013-04-30 [expired: 2017-04-30]
uid                  Scala Project <scala-internals@googlegroups.com>
```

I had previously created a new signature on the public key with a new expiry date on my own machine:

```
➜  ~ gpg --list-key                                                            
/Users/adriaan/.gnupg/pubring.gpg
---------------------------------

pub   rsa2048 2013-04-30 [SCEA] [expires: 2019-05-16]
      3D3A4396458FD629DEAE0F88E9DF618BB41F2BCE
uid           [ unknown] Scala Project <scala-internals@googlegroups.com>
sub   rsa2048 2013-04-30 [SEA] [expires: 2019-05-16]
```

So, I did

```
gpg -a --export 3D3A4396458FD629DEAE0F88E9DF618BB41F2BCE > 3d3a.key  
scp 3d3a.key jenkins-worker-ubuntu-publish:~/
```

and on the worker:
```
jenkins@ip-172-31-15-209:/home/ubuntu$ gpg --import 3d3a.key 
gpg: key B41F2BCE: "Scala Project <scala-internals@googlegroups.com>" 3 new signatures
gpg: Total number processed: 1
gpg:         new signatures: 3
gpg: no ultimately trusted keys found
jenkins@ip-172-31-15-209:/home/ubuntu$ gpg --list
gpg: Option "--list" is ambiguous
jenkins@ip-172-31-15-209:/home/ubuntu$ gpg --list-keys
/home/jenkins/.gnupg/pubring.gpg
--------------------------------
pub   2048R/B41F2BCE 2013-04-30 [expires: 2019-05-16]
uid                  Scala Project <scala-internals@googlegroups.com>
sub   2048R/202D3646 2013-04-30 [expires: 2019-05-16]
```


## Alternate JDK installation

Jason installed, or plans to install, Graal, Java 9 and J9 JDKs on the behemoth-workers to support. I'll add a transcript here when I next update them.

## cloc

Seth did `sudo apt-get install cloc` on behemoth 2 so we can count lines of code in the
Scala community build.

## curl

Adriaan installed curl to /usr/bin/curl.exe (how?)

## ant

Adriaan installed ant to /cygdrive/c/apache-ant-1.9.6: "just unzip the archive and set ANT_HOME and PATH accordingly in windows node env vars", he writes

## Git

Seth installed Git 2.5.3 to /cygdrive/c/Program Files (x86)/Git-2.5.3 by downloading a GUI-based installer from https://git-for-windows.github.io (I think it was from there and not http://www.git-scm.com, or does it even matter?) and running it through CoRD.

the needed longpaths setting is done through Chef via recipes/_worker-config-windows-cygwin.rb

## JDK 8

"we have also contemplated manually installing JDK 8 as a quick and
dirty way to get the 2.12 tests running on Windows (#142)" -- did this happen?
not sure
