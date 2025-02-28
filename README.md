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


## Webhooks, tokens, accounts etc

  - Jenkins auth via GitHub. GitHub OAuth App owned by the Scala org: https://github.com/organizations/scala/settings/applications/154904
  - Scabot posts build status to GitHub using an access token of the scala-jenkins user: https://github.com/settings/tokens
  - Scabot starts Jenkins builds using an access token of the scala-jenkins user (log in to GitHub as scala-jenkins, then to Jenkins): https://scala-ci.typesafe.com/user/scala-jenkins/security/
  - GitHub webhooks to notify scabot: https://github.com/scala/scala/settings/hooks
  - Jenkins webhooks to notify scabot: Job configuration, notifications: e.g., https://scala-ci.typesafe.com/job/scala-2.13.x-validate-main/configure
  - Jenkins workers: ssh, credentials: https://scala-ci.typesafe.com/manage/credentials/
  - Jenkins plugin to start / stop workers: auth unclear, see README in https://github.com/lightbend-labs/ec2-start-stop


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



## Installed services

### nginx

Nginx for `scala-ci.typesafe.com` on `jenkins-master`, `/etc/nginx/conf.d/jenkins.conf`.

Handles jenkins, `/artifactory`, `/grafana`, `/benchq`, ...

### Jenkins

Auth goes via GitHub. In the [configuraton](https://scala-ci.typesafe.com/manage/configureSecurity/) there's a field "Admin User Names".

AWS Workers are started / stopped by custom jenkins plugin: https://github.com/lightbend-labs/ec2-start-stop

TODO: how to get logs?
  - After a recent upgrade, scabot was no longer receiving job notifications from jenkins (it fixed itself...)
  - lrytz didn't figure out how to enable debug logs in jenkins
  - The notifications plugin [produces logs](https://github.com/jenkinsci/notification-plugin/blob/notification-1.17/src/main/java/com/tikal/hudson/plugins/notification/Phase.java#L386), but no idea how to enable / find them

### Artifactory

`scala-ci.typesafe.com/artifactory/` to log in to the UI.

Repositories:
  - `scala-pr-validation-snapshots`
  - `scala-integration` for mergely builds
  - `dbuild` / `dbuild-ivy` are aggregates of cached remote repositories. used for the community build.

File locations
  - config file: `/opt/jfrog/artifactory/var/etc/system.yaml`
  - `sudo tail -f /opt/jfrog/artifactory/var/log/console.log` has aggregated logs, logs for individual services in the same directory
  - `/opt/jfrog/artifactory/var` is a symlink to `/var/opt/jfrog/artifactory`
  - `/var/opt/jfrog/artifactory/data` is a separate mount (600G volume)
  - `data/filestore` stores the data (artifacts are stored with their hash as filename for deduplication, possible sharding)
  - `data/backup` for manual and automated backups

Database
  - apt-installed postgres, details see `system.yaml`
  - `/var/lib/postgresql` is a symlink to `/var/opt/jfrog/artifactory/data/postgresql-data` on the 600G artifactory volume

Upgrading artifactory
  - breaking changes seem common! release notes: https://jfrog.com/help/r/jfrog-release-information/artifactory-self-hosted-releases
  - `jfrog-artifactory-oss` apt package
  - backup: use "Export System" in the UI to `/var/opt/jfrog/artifactory/data/backup/export`, check "Exclude Content"
    - `sudo tail -f /opt/jfrog/artifactory/var/log/console.log` to see if it's done, UI will time out
    - restore: [start with an empty database](https://jfrog.com/help/r/jfrog-installation-setup-documentation/create-the-artifactory-postgresql-database), import from `/var/opt/jfrog/artifactory/data/backup/export/...`
    - `data/filestore` should not be affected. maybe there's a danger if GC starts when running the empty instance?

### Scabot

[Scabot](https://github.com/scala/scabot) triggers Jenkins builds and updates their state on github commits / PRs.

  - Logs: `journalctl -u scabot -f -n 100`

## Details

### AWS CLI

  - `brew install awscli`
  - via okta, go to AWS IAM
  - unfold the "EngOps Scala" entry, click "Access keys" to get the `SSO start URL` and `SSO Region`
  - `aws configure sso`
  - set `AWS_DEFAULT_PROFILE`
  - `aws ec2 describe-instances` to test

### Disk usage

Use `ncdu -x /path` to analyze disk usage.

### Jenkins workers disk space

  - Change "Idle delay" of Jenkins worker to 500 (https://scala-ci.typesafe.com/computer/jenkins-worker-behemoth-1/configure)
    - prevents shutting down while the files are being deleted
  - `ssh jenkins-worker-behemoth-1`
  - delete `/home/jenkins/workspace/*community*`, `/home/jenkins/.dbuild`, `/home/jenkins/workspace/*tmp`
  - Revert "Idle delay" to 5
  - More details: https://github.com/scala/community-build/wiki/Maintenance#servers-run-out-of-disk-space

### Artifactory disk usage

Artifactory disk usage report: https://scala-ci.typesafe.com/ui/admin/monitoring/storage-summary.

<details>
  <summary>Steps to delete old builds from <code>scala-pr-validation-snapshots</code>:</summary>

Create a file `search.json`, adjust the cutoff date on the last line:

```
items.find({
  "repo": "scala-pr-validation-snapshots",
  "$or": [ { "name": { "$match": "scala-compiler*" } }, {"name": { "$match": "scala-reflect*" } }, { "name": { "$match": "scala-library*" } }, { "name": { "$match": "scala-dist*" } }, { "name": { "$match": "scala-partest*" } }, { "name": { "$match": "scalap*" } } ],
  "created": { "$lt": "2020-01-01" }
})
```

`curl -u 'lukas:SEEEKREET' -X POST "https://scala-ci.typesafe.com/artifactory/api/search/aql" -T search.json > artifacts.json`

In an up-to-date Scala 2.13.x checkout, the following tests which of the artifacts correspond to revisions that were actually merged into scala/scala. Builds for those revisions are kept, builds for revisions that never made it are added to `to-delete.txt`.

```bash
n=$(cat artifacts.json | jq -r '.results[] | .path' | uniq | wc -l)
for p in $(cat artifacts.json | jq -r '.results[] | .path' | uniq); do
  n=$((n-1))
  sha=$(echo $p | awk -F'-' '{print $(NF-1)}')
  if git branch --contains $sha | grep 2.13.x > /dev/null; then
    echo "$sha y - $n"
  else
    echo "$sha n - $n"
    echo $p >> to-delete.txt
  fi
done
```

Delete the artifacts; best run it on `ssh jenkins-master` for performance.

```bash
n=$(cat to-delete.txt | wc -l)
for p in $(cat to-delete.txt); do
  n=$((n-1))
  echo "$p - $n"
  curl -u 'lukas:PASSWORDSEKRET' -X DELETE "https://scala-ci.typesafe.com/artifactory/scala-pr-validation-snapshots/$p"
done
```

After that
  - Empty "Trash Can"
    - `curl -I -u 'lukas:SEEEKREET' -X POST "https://scala-ci.typesafe.com/artifactory/api/trash/empty"`
  - Run artifactory's "Garbage Collection" [20 times (😆)](https://jfrog.com/knowledge-base/why-does-removing-deleting-old-artifacts-is-not-affecting-the-artifactory-disk-space-usage/)
    - `for i in {1..20}; do curl -I -u 'lukas:SEEEKREET' -X POST "https://scala-ci.typesafe.com/artifactory/api/system/storage/gc"; done`
    - wait for it to complete, it runs in the background. check Binaries Size / Artifacts Size in Storage
  - Run "Prune Unreferenced Data"
    - `api/system/storage/optimize`
  - https://jfrog.com/knowledge-base/what-is-the-difference-between-garbage-collector-and-prune-unreferenced-data-processes-in-artifactory/

Other measures
  - https://scala-ci.typesafe.com/ui/admin/artifactory/configuration/artifactory_general "Empty Trash Can"
  - Derby database (`/var/opt/jfrog/artifactory/data/derby/seg0`) may be big.
    - https://scala-ci.typesafe.com/ui/admin/artifactory/advanced/maintenance "Compress the Internal Database".
    - Did not work for me. "lock could not be obtained due to a deadlock".
    - Doc says "We recommend running this when Artifactory activity is low, since compression may not be able to complete when storage is busy (in which case the storage will not be affected)."

</details>

### Resize drives / file systems

Enlarging drives and their partitions seems to work well, even for the root partition of a running system (Debian).

  - Take a snapshot of the EBS Volume, wait for it to be completed
  - Use "Modify volume" and increase the size
  - Increase the partition and file system sizes ([details here](https://docs.aws.amazon.com/ebs/latest/userguide/recognize-expanded-volume-linux.html))
    - `sudo growpart /dev/nvme0n1 1` (if there are partitions)
    - `sudo resize2fs /dev/nvme0n1p1`

### Recreate drive

To recreate a drive / file system (to shrink it, or to move to a different file system), create a new EBS volume, mount it and copy the data over using `rsync`.
  - new EBS volume, gp3, 400g, default iops/throughput. us-west-1c.
  - attach to instance as `/dev/xvdN`
  - `lsblk`
  - `mkfs -t ext4 -N 50000000 /dev/xvdN` (`-N` to specify the [number of inodes](https://github.com/scala/community-build/issues/1633); `df -hi` to display)
  - `mkdir /home/jenkins-new`
  - `chown jenkins:root /home/jenkins-new`
  - `blkid` to show UUID
  - fstab: `UUID=YYYYYYYYYYYYYYYY /home/jenkins-new ext4 noatime 0 0`
  - `systemctl daemon-reload`
  - `mount -a`
  - `chown jenkins:root /home/jenkins-new`
  - `rsync -a -H --info=progress2 --info=name0 /home/jenkins/ /home/jenkins-new/`
    -  `-H` is important, git checkouts use hard links
  - fstab, mount new volume at `/home/jenkins`. comment out old volume
  - `systemctl daemon-reload`
  - `reboot` (old volume might be in use)


### Unattended upgrades

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
