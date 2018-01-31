scalaCiHost = "scala-ci.typesafe.com"
scalaCiPort = 443
scabotPort  = 8888

# JENKINS WORKER CONFIG


default['repos']['private']['realm']        = "Artifactory Realm"
default['repos']['private']['host']         = scalaCiHost
default['repos']['private']['pr-snap']      = "https://#{scalaCiHost}/artifactory/scala-pr-validation-snapshots/"
default['repos']['private']['integration']  = "https://#{scalaCiHost}/artifactory/scala-integration/"

default['repos']['caching-proxy']['central']['mirrorOf'] = "central" # TODO: add ",sonatype.release,sonatype.snapshot"
default['repos']['caching-proxy']['central']['url']      = "https://#{scalaCiHost}/artifactory/central/"
default['repos']['caching-proxy']['jcenter']['mirrorOf'] = "jcenter" # TODO: add ",sonatype.release,sonatype.snapshot"
default['repos']['caching-proxy']['jcenter']['url']      = "https://#{scalaCiHost}/artifactory/jcenter/"

default['s3']['downloads']['host'] = "downloads.typesafe.com.s3.amazonaws.com"

# bumped to sbt-extras as of 30 Jan 2018 (commit date 13 Dec 2017)
default["sbt-extras"]["download_url"] = "https://raw.githubusercontent.com/paulp/sbt-extras/d28a7e41fdb49941e8ba7d50cdb9f9cb98efd26a/sbt"

# JAVA
# TODO does this actually do anything???
# it seemed I had to do a `node.set['java']['jdk_version'] = 8` on jenkins-master to actually get this to work
default['java']['jdk_version']    = '8'
default['java']['install_flavor'] = 'openjdk'

# the artifactory recipe does `node.set['java']['jdk_version'] = 7` unless this is false....
default['artifactory']['install_java'] = false


# attributes only needed on jenkins-master
if node.name == "jenkins-master"
  # EBS
  default['ebs']['volumes']['/var/lib/jenkins']['size']      = 100 # size of the volume correlates to speed (in IOPS)
  default['ebs']['volumes']['/var/lib/jenkins']['dev']       = "/dev/sdj"
  default['ebs']['volumes']['/var/lib/jenkins']['fstype']    = "ext4"
  default['ebs']['volumes']['/var/lib/jenkins']['user']      = "jenkins"
  default['ebs']['volumes']['/var/lib/jenkins']['mountopts'] = 'noatime'

  default['ebs']['volumes']['/var/lib/artifactory']['size']      = 200 # size of the volume correlates to speed (in IOPS)
  default['ebs']['volumes']['/var/lib/artifactory']['dev']       = "/dev/sdk"
  default['ebs']['volumes']['/var/lib/artifactory']['fstype']    = "ext4"
  default['ebs']['volumes']['/var/lib/artifactory']['user']      = "artifactory"
  default['ebs']['volumes']['/var/lib/artifactory']['mountopts'] = 'noatime'

  # ARTIFACTORY
  default['artifactory']['zip_url']            = 'https://dl.bintray.com/content/jfrog/artifactory/jfrog-artifactory-oss-4.7.4.zip?direct'
  default['artifactory']['zip_checksum']       = '05ccc6371a6adce0edb7d484a066e3556a660d9359b9bef594aad2128c1784f2'
  default['artifactory']['home']               = '/var/lib/artifactory'
  default['artifactory']['log_dir']            = '/var/lib/artifactory/logs'
  default['artifactory']['java']['xmx']        = '2g'
  default['artifactory']['java']['extra_opts'] = '-server'
  default['artifactory']['user']               = 'artifactory'
  default['artifactory']['proxyName']          = scalaCiHost
  default['artifactory']['proxyPort']          = scalaCiPort
  default['artifactory']['address']            = "localhost"
  default['artifactory']['port']               = 8282 # internal use over http

  # JENKINS
  override['jenkins']['master']['install_method'] = 'war'
  override['jenkins']['master']['listen_address'] = '127.0.0.1' # external traffic must go through nginx
  override['jenkins']['master']['user']           = 'jenkins'
  override['jenkins']['master']['group']          = 'jenkins'

  override['jenkins']['java'] = '/usr/lib/jvm/java-1.8.0/bin/java' # need java 8!
  override['jenkins']['executor']['protocol'] = false # jenkins 1.x does not support specifying the remoting protocol for the cli

  # NOTES on override['jenkins']['master']['jvm_options']:
  #  - org.eclipse.jetty.server.Request.maxFormContentSize is to fix:
  #     WARNING: Caught exception evaluating: request.getParameter('q') in /updateCenter/byId/default/postBack. Reason: java.lang.IllegalStateException: Form too large 870330>500000

  #  - hudson.model.User.allowNonExistentUserToLogin resolves issue with installing plugins
  #    on bootstrapping jenkins (https://github.com/jenkinsci/jenkins/commit/80e9f3f50c3425c9b9b2bfdb58b03a1f1bd10aa3)
  #   more of the stacktrace:
  #      java.io.EOFException
  #      	at java.io.DataInputStream.readBoolean(DataInputStream.java:244)
  #      before that:   #  ================================================================================
  #      Error executing action `install` on resource 'jenkins_plugin[notification]'
  #      ================================================================================
  #
  #      Mixlib::ShellOut::ShellCommandFailed
  #      ------------------------------------
  #      Expected process to exit with [0], but received '255'
  #      ---- Begin output of "/usr/lib/jvm/java-7-openjdk-amd64/bin/java" -jar "/var/chef/cache/jenkins-cli.jar" -s http://localhost:8080 -i "/var/chef/cache/jenkins-key" install-plugin /var/chef/cache/notification-latest.plugin -name notification  ----

  override['jenkins']['master']['jvm_options']    = '-server -Xmx4G -XX:MaxPermSize=512M -XX:+HeapDumpOnOutOfMemoryError -Dhudson.model.User.allowNonExistentUserToLogin=true -Dorg.eclipse.jetty.server.Request.maxFormContentSize=1000000 -Dhudson.diyChunking=false' #
  # -Dfile.encoding=UTF-8

  override['jenkins']['master']['version']  = '1.658'
  override['jenkins']['master']['source']   = "#{node['jenkins']['master']['mirror']}/war/#{node['jenkins']['master']['version']}/jenkins.war"
  override['jenkins']['master']['checksum'] = '108a496a01361e598cacbcdc8fcf4070e4dab215fb76f759dd75384af7104a3c'

  ## GITHUB OAUTH
  default['master']['github']['webUri']                               = 'https://github.com/'
  default['master']['github']['apiUri']                               = 'https://api.github.com'
  default['master']['github']['adminUserNames']                       = 'adriaanm, retronym, lrytz, SethTisue, smarter, DarkDimius, chef, scala-jenkins, szeiger, dwijnand'
  default['master']['github']['oauthScopes']                          = 'read:org,user:email'
  default['master']['github']['organizationNames']                    = 'scala'
  default['master']['github']['useRepositoryPermissions']             = 'true'
  default['master']['github']['allowAnonymousReadPermission']         = 'true'
  default['master']['github']['allowAnonymousJobStatusPermission']    = 'true'
  default['master']['github']['authenticatedUserReadPermission']      = 'true'
  default['master']['github']['allowGithubWebHookPermission']         = 'true'
  default['master']['github']['allowCcTrayPermission']                = 'false'
  default['master']['github']['authenticatedUserCreateJobPermission'] = 'false'

  ## CONTACT INFO
  default['master']['adminAddress']         = "adriaan@lightbend.com"
  default['master']['jenkinsHost']          = scalaCiHost
  default['master']['jenkinsUrl']           = "https://#{scalaCiHost}/"
  default['master']['jenkins']['notifyUrl'] = "http://#{scalaCiHost}:#{scabotPort}/jenkins" # scabot listens here
  default['master']['jenkins']['benchqUrl'] = "https://#{scalaCiHost}/benchq/webhooks/jenkins"


  ## PLUGIN
  default['master']['ec2-start-stop']['url'] = 'https://dl.dropboxusercontent.com/u/12862572/ec2-start-stop.hpi'

  # SCABOT
  default['scabot']['jenkins']['user'] = "scala-jenkins"
  default['scabot']['port'] = scabotPort

end
