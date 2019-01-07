# Overview

Things our Jenkins-based CI infrastructure does:

* (automatically) validate all commits, including
  the ones in pull requests
* (automatically) run the [community build](https://github.com/scala/community-builds)
* (automatically) build nightly releases
* (manually) run scripts at release time

All of these are described in greater detail below.

## A note on Travis-CI

Many of the smaller repos under the scala organization
(for example, [scala-xml](https://github.com/scala/scala-xml))
use [Travis-CI](http://travis-ci.org) for continuous integration.
Travis requires the least setup or administration, so it's the easiest
way for maintainers from the open-source community to participate.
The Travis configs (in `.travis.yml` files in each
repository root) are generally self-contained and straightforward.

But for the [main Scala repository](https://github.com/scala/scala)
itself, we have found that we want the full power of Jenkins: for
capacity, for performance, and for full control over every aspect of
the builds.  Also, we want to build every commit, not just every push.

(We do, however, try to design our Jenkins configurations to be
consistent, within reason, with a possible eventual move to Travis.)

The rest of this document describes Jenkins only.

## Infrastructure

The web UI for Jenkins is at https://scala-ci.typesafe.com.

The Jenkins infrastructure runs on virtual servers hosted by
Amazon.  The virtual servers are created and configured automatically
via Chef.  Everything is scripted and the scripts version-controlled
so the servers can automatically be rebuilt at anytime.  This is all
described in more detail below.


### Pull request validation

Every commit must pass a series of checks before the PR's "build
status" becomes green:

* `cla` -- verify that the submitter of the PR has digitally signed
  the Scala CLA using their GitHub identity.  (Handled by Scabot,
  not Jenkins.)
* `validate-main` -- top-level Jenkins job.
  Does no work of its own, just orchestrates the other jobs
  as follows: runs `validate-publish-core` first, and if it succeeds,
  then runs `validate-test` and `integrate-ide` in parallel.
* `validate-publish-core` -- build Scala and publish artifacts via
  Artifactory on scala-ci. The resulting artifacts are used during the
  remaining stages of validation.  The artifacts can also be used for
  manual testing; instructions for adding the right resolver and
  setting `scalaVersion` appropriately are in the
  [Scala repo README](https://github.com/scala/scala/blob/2.11.x/README.md).
* `validate-test` -- run the Scala test suite
* `integrate-ide` -- run the ScalaIDE test suite

Normally, every commit in the PR (not just the last commit) must pass
all checks.  Putting `[ci: last-only]` in the PR title tells Scabot to
validate the last commit only.

In the future, we plan to make the [Scala community build]
(https://github.com/scala/community-builds) part of PR validation
as well.

PR validation is orchestrated by Scabot, as documented in the
[scabot repo](https://github.com/scala/scabot).  In short, Scabot runs
on jenkins-master, listens to GitHub and Jenkins, starts
`validate-main` jobs on Jenkins when appropriate, and updates PRs'
build statuses.

### Pushed commit validation

Besides commits in pull requests, what other commits require validation?

* Scabot ensures that every commit in a pull request gets validated.
  But when the pull request is merged, a new merge commit is created,
  and that commit must be validated, too.
* The Scala team has a policy of always using pull requests, never
  pushing directly to mainline branches.  But if such a direct push
  somehow happens anyway, we want to validate those commits, too.

So in addition to watching pull requests, Scabot also watches
for other pushes, including merges, and starts jobs for and updates
statuses on the pushed commits, too.

### Naming

The Jenkins job names always correspond exactly with the names of the
scripts in the repo's `scripts` directory, uniformly across orgs (e.g. scala vs. lampepfl)
and branches.  So for example, validate-test is the name of a job conceptually,
scala-2.11.x-validate-test is the Jenkins name for the job running on
2.11.x in the scala org (since we can't make "virtual" jobs in jenkins
that group by parameter, otherwise we wouldn't need this name
mangling), and the actual script that runs is
https://github.com/scala/scala/blob/2.11.x/scripts/jobs/validate/test.

Exception: "main" jobs are always
[Flow DSL](https://wiki.jenkins-ci.org/display/JENKINS/Build+Flow+Plugin)
meta-jobs with no associated script.

In the job names, `validate` means the job operates on only one repo;
`integrate` means it brings multiple projects/repos together.

### Community build

The community build uses an open-source tool we developed called
[dbuild](https://github.com/typesafehub/dbuild).

The dbuild configuration files that specify the Scala community
build live in https://github.com/scala/community-builds.

### Nightly releases

A suite of Jenkins configs with `-release-` in the name uses
the scala/scala and scala/scala-idst repos to make nightly
releases, including installers and Scaladoc, and makes them available
from http://www.scala-lang.org/files/archive/nightly/
and http://www.scala-lang.org/api/nightly/.

(In the scripts that handle this, `chara` refers to the server that
hosts scala-lang.org.)

### "Real" releases

Some of the Jenkins configs relate to building "real" (non-nightly)
Scala releases and are manually, not automatically, triggered,
using Jenkins' "Build with parameters" feature:

* scala-2.11.x-release-website-update-current
* scala-2.11.x-release-website-update-api

### Artifactory

The master node includes an Artifactory repository that serves
several purposes:

* during PR validation, artifacts are (as already mentioned above) published to
  https://scala-ci.typesafe.com/artifactory/scala-pr-validation-snapshots/
* during release-building, artifacts are published along the way for
  use as part of the build process
* the community build caches artifacts with Artifactory, so it
  doesn't have to re-download the internet all the time;
  this vastly increases the speed of the community build

### User accounts

To isolate it, Scabot runs as the `scabot` user (on jenkins-master),
confined to its home directory.

To isolate it, Jenkins always runs as the `jenkins` user, confined to
its home directory, on both master and workers.  (The master doesn't
run actual jobs; it initiates jobs by ssh'ing to the workers.)

On the master, the admin user is `ec2-user`. On the workers, the admin
users is `ubuntu`.  These are the standard EC2 accounts for Amazon
Linux and Ubuntu, respectively.  They can `sudo`.

### How we built it

The first iteration used Chef. We've now moved to ansible. See site.yml and the various config files / templates under `roles/`. There's also a `Vagrantfile` for local experimentation.

### More documentation

* [design.md](design.md): further notes on the design of
  the whole setup
* [client-setup.md](client-setup.md): how to set up your local
  machine to talk to the existing CI infrastructure
* [maintenance.md](maintenance.md): how to maintain, troubleshoot,
  and update the CI infrastructure
* [genesis.md](genesis.md): how the infrastructure was initially
  created, and how to re-create it if needed
     * [recreate-jenkins-master.md](recreate-jenkins-master.md)
