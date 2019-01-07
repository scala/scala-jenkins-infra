(Adriaan's original notes. some of this material is now covered
in overview.md. some pieces may be only historical now)

# Design for scala-ci.typesafe.com

Jenkins on EC2, configured using ansible (not documented since it happened in a rush when moving away from chef...)

* centered around GitHub & future move to Travis CI
   * no nightly builds (not supported on Travis) -- run integration on every merge
   * a job is tied to a main repo, which has the code it’s building/testing + scripts to do so (script is named after jenkins job)
   * minimize turnaround time, CPU/RAM usage (EC2 nodes have 7.5 GiB RAM / 4 vCPUs)
   * jobs have same set of params that define the tested commit (user/repo#gitref)
      * for testing, can be changed to different github user/gitref
* job concisely captures all relevant data
   * jenkins gives us: changes since last build (since 1 job = 1 repo)
   * job-specific params incorporated into job title
* use jenkins strictly as a job scheduler/dashboard
   *  archive logs, builds elsewhere
   *  configuration is handled by ansible
* the jenkins server/workers are considered stateless & opaque
   * infrastructure is fully defined in ansible config
   * worker nodes have home directory mounted on device that is wiped on reboot (ephemeral storage on EC2)
   * as little information as possible in jenkins job config: standardize common stuff & extract logic to scripts
* use maven to store and communicate compiled artifacts
   * every commit has artifacts on our artifactory, use them for running test suite downstream, git bisect,...
   * can we move to a cycle where modules are always built with a previous, binary compatible (possibly internal, e.g., 2.12.0-strap used to bootstrap 2.12.0) release, well before the public release, so that we can always run the release job in one go?
* tag jobs
   *  public  --> for security, PR validation etc can only run on worker with this label (other workers have API keys etc for publishing)
   *  publish --> has sensitive data to allow publishing -- only run after merge
   *  linux/windows
* move away from bash, towards sbt
* use small repeatable, jobs
* pr validation
   * validates every commit builds, passes test suite (don’t test integration -- that’s done after merge)
   * doesn’t test merged commit because it’s a lie (target branch may move before merge button is clicked --> merged commits are tested separately, replacing current nightly build)
   * github webhook:
      * ensures the scala-pr-validator flow is started on jenkins with the right params
      * sets milestone
      * adds reviewed label
   * jenkins:
      * the flow pings the webhook when it starts, so it can be removed from the pr-validator's queue
      * each job in the flow sets the commit status (github now supports multiple reporters per commit)
      * each job in the flow can be restarted on jenkins (and will adjust the commit’s status by the previous bullet)

# TODO

* test security setting/authentication
* mergely builds instead of nightlies
   * We had about 1.8 merges per day on scala/scala in 2014 (merged 634 of 1100 received PRs), so it seems feasible to move from nightly to “mergely” builds
   * every commit should be built only once, published to artifactory
   * run test suite using published compiler instead of rebuilding it
   * release job (== nightly) runs for every merge commit


# Jobs

* build core (library/reflect/compiler)
* run test suite
* full integration testing
   * rangepos
   * IDE
   * community build
* scala/scala-dist packaging

# Timing

* every commit must build and pass test suite, on the default part of the matrix
* other jobs * full matrix: only on merge

# Matrix

* unix | windows
* jdk 6|7|8|9

## Reduce builder load

* windows builder only used for merge commits:
   * packaging for release (jdk 6)
   * test suite (jdk 6|8)

# Dimensioning

Starting cost, monthly cost between $170 - $300:  (us-west-1 == oregon):

```text
master:           $40  for t2.medium  (2 vCPU, 4 GiB RAM, EBS Only)      (24 hr/day * 31 day/month * $0.052/hr)
windows:          $25  for m3.medium  (1 vCPU, 3.75 GiB RAM, 1 x 4 SSD)  ( 6 hr/day * 31 day/month * $0.133/hr)
ubuntu:          $105  for c3.xlarge  (4 vCPU, 7.5 GiB RAM, 2 x 40 SSD)  (16 hr/day * 31 day/month * $0.210/hr)
builder-prime: < $130  for c3.xlarge  (4 vCPU, 7.5 GiB RAM, 2 x 40 SSD)  (20 hr/day * 31 day/month * $0.210/hr)
```

Once we gain some experience, use reserved instances (prefer amazon linux because the reserved instance type can be changed), tentatively:

```text
master:         $73    for m3.large   (2 vCPU, 7.5 GiB RAM, 1 x 32 SSD)
ubuntu:        $106.58 for c3.xlarge  (4 vCPU, 7.5 GiB RAM, 2 x 40 SSD)
```

# References

http://soldering-iron.blogspot.com/2014/01/big-jenkins-servers-of-2013.html
