# Jenkins-based CI for the Scala project

Used for
  - Scala 2.12 / 2.13 PR validation
  - Scala 2.12 / 2.13 [community build](https://github.com/scala/community-builds)

Old documentation in [doc](doc/) directory; some pieces are still relevant, some are outdated.

## History

The AWS infra was originally deployed and maintanied using ansible (this repo).
We no longer use ansible to update the infra, but manage it manually (AWS console, ssh to the machines, jenkins UI, artifactory UI).

We are gradually moving away from using this infra
  - releases and integration builds are published on travis / appveyor
  - mergely tests for windows and on various jdks on github actions

But we still need it because
  - where would we put PR / integration builds?
  - where would we get enough resources to run the community build?

## SSH access

<details>
  <summary>Add the following to your <code>~/.ssh/config</code></summary>

  ```
  Host jenkins-master
    HostName 54.67.111.226
    User admin
  
  Host jenkins-worker-behemoth-1
    HostName 54.153.2.9
    User admin
  
  Host jenkins-worker-behemoth-2
    HostName 54.153.1.99
    User admin
  
  Host jenkins-worker-behemoth-3
    HostName 54.183.156.89
    User admin
  
  # no public ip, jumphost through master
  Host influxdb
    HostName 172.31.0.100
    User ubuntu
    ProxyCommand ssh -q -W %h:%p jenkins-master
  ```

</details>



## Installed Services

### nginx

Nginx for `scala-ci.typesafe.com` on `jenkins-master`, `/etc/nginx/conf.d/jenkins.conf`.

Handles jenkins, `/artifactory`, `/grafana`, `/benchq`, ...

### Jenkins

Auth goes via GitHub.

TODO: how to get logs?
  - After a recent upgrade, scabot was no longer receiving job notifications from jenkins (it fixed itself...)
  - lrytz didn't figure out how to enable debug logs in jenkins
  - The notifications plugin [produces logs](https://github.com/jenkinsci/notification-plugin/blob/notification-1.17/src/main/java/com/tikal/hudson/plugins/notification/Phase.java#L386), but no idea how to enable / find them

### Artifactory

`scala-ci.typesafe.com/artifactory/` to log in to the UI.

Repositories:
  - `scala-pr-validation-snapshots`
  - `scala-integration` for mergely builds
  - `dbuild` is an aggregate of cached remote repositories. used for the community build.

The config file is `/opt/jfrog/artifactory/var/etc/system.yaml`.

`/opt/jfrog/artifactory/var/log/console.log` has aggregated logs, logs for individual services in the same directory.

`/opt/jfrog/artifactory/var/data/derby` is the main database for our artifactory; its large (19G in Aug 2024).

The `access` service has its own db at `/opt/jfrog/artifactory/var/data/access/derby`.

### Scabot

[Scabot](https://github.com/scala/scabot) triggers Jenkins builds and updates their state on github commits / PRs.

## Details

### Unattended Upgrades

Enabled on master and behemoths
  - default config on behemoths, installs all updates.
  - only security updates on master, plus jenkins. Not artifactory because an `apt upgrade` of it doesn't restart the service. Also, artifactory updates tend to be more breaking.

### JVM installations

Only a basic jre is installed through apt (eg `openjdk-17-jre-headless`).

Use `sudo su` and cd to `/usr/lib/jvm`, see the `README` file.
Install new JDKs here, we default to adoptium.

### chrony

On all machines (`chronyc tracking` to check):

```
root@ip-172-31-10-237:~# cat /etc/chrony/sources.d/aws.sources
#https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-ec2-ntp.html
server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4
```
