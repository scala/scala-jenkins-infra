scalaCiHost = "scala-ci.typesafe.com"
scalaCiPort = 443

# JENKINS WORKER CONFIG
default['repos']['private']['realm']        = "Artifactory Realm"
default['repos']['private']['host']         = "private-repo.typesafe.com"
default['repos']['private']['pr-snap']      = "http://private-repo.typesafe.com/typesafe/scala-pr-validation-snapshots/"
default['repos']['private']['release-temp'] = "http://private-repo.typesafe.com/typesafe/scala-release-temp/"
default['s3']['downloads']['host'] = "downloads.typesafe.com.s3.amazonaws.com"

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

  # JAVA
  default['java']['jdk_version']    = '7'
  default['java']['install_flavor'] = 'openjdk'

  # ARTIFACTORY
  default['artifactory']['zip_url']            = 'http://dl.bintray.com/content/jfrog/artifactory/artifactory-3.6.0.zip?direct'
  default['artifactory']['zip_checksum']       = '72c375ab659d302da0b196349e152f3d799c3cada2f4d09f9399281a06d880e8'
  default['artifactory']['home']               = '/var/lib/artifactory'
  default['artifactory']['log_dir']            = '/var/lib/artifactory/logs'
  default['artifactory']['java']['xmx']        = '2g'
  default['artifactory']['java']['extra_opts'] = '-server'
  default['artifactory']['user']               = 'artifactory'
  default['artifactory']['proxyName']          = scalaCiHost
  default['artifactory']['proxyPort']          = scalaCiPort
  default['artifactory']['address']            = "localhost"
  default['artifactory']['port']               = 8282 # internal use over http
  default['artifactory']['install_java']       = false

  # JENKINS
  override['jenkins']['master']['install_method'] = 'war'
  override['jenkins']['master']['listen_address'] = '127.0.0.1' # external traffic must go through nginx
  override['jenkins']['master']['user']           = 'jenkins'
  override['jenkins']['master']['group']          = 'jenkins'

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

  override['jenkins']['master']['jvm_options']    = '-server -Xmx4G -XX:MaxPermSize=512M -XX:+HeapDumpOnOutOfMemoryError -Dhudson.model.User.allowNonExistentUserToLogin=true -Dorg.eclipse.jetty.server.Request.maxFormContentSize=1000000' #
  # -Dfile.encoding=UTF-8

  # To pin the jenkins version, must also override override['jenkins']['master']['source'] !!!
  # override['jenkins']['master']['version']  = '1.555'
  # override['jenkins']['master']['source']   = "#{node['jenkins']['master']['mirror']}/war/#{node['jenkins']['master']['version']}/jenkins.war"
  # override['jenkins']['master']['checksum'] = '31f5c2a3f7e843f7051253d640f07f7c24df5e9ec271de21e92dac0d7ca19431'

  ## GITHUB OAUTH
  default['master']['github']['webUri']                               = 'https://github.com/'
  default['master']['github']['apiUri']                               = 'https://api.github.com'
  default['master']['github']['adminUserNames']                       = 'adriaanm,retronym,lrytz,chef,scala-jenkins'
  default['master']['github']['organizationNames']                    = 'scala'
  default['master']['github']['useRepositoryPermissions']             = 'true'
  default['master']['github']['allowAnonymousReadPermission']         = 'true'
  default['master']['github']['authenticatedUserReadPermission']      = 'true'
  default['master']['github']['allowGithubWebHookPermission']         = 'true'
  default['master']['github']['allowCcTrayPermission']                = 'false'
  default['master']['github']['authenticatedUserCreateJobPermission'] = 'false'

  ## CONTACT INFO
  default['master']['adminAddress']         = "adriaan@typesafe.com"
  default['master']['jenkinsHost']          = scalaCiHost
  default['master']['jenkinsUrl']           = "https://#{scalaCiHost}/"
  default['master']['jenkins']['notifyUrl'] = "http://#{scalaCiHost}:8888/jenkins" # scabot listens here

  # see below (note that default['master']['env'] can only indirect through node -- workerJavaOpts is not in scope)
  workerJavaOpts = "-Dfile.encoding=UTF-8 -server -XX:+AggressiveOpts -XX:+UseParNewGC -Xmx2G -Xss1M -XX:MaxPermSize=512M -XX:ReservedCodeCacheSize=128M -Dpartest.threads=4"
  default['jenkinsEnv']['JAVA_OPTS']  = workerJavaOpts
  default['jenkinsEnv']['ANT_OPTS']   = workerJavaOpts
  default['jenkinsEnv']['MAVEN_OPTS'] = workerJavaOpts # doesn't technically need the -Dpartest one, but oh well

  # NOTE: This is a string that represents a closure that closes over the worker node for which it computes the environment.
  # (by convention -- see `environment((eval node["master"]["env"])...` in _master-config-workers
  # Since we can't marshall closures, while attributes need to be sent from master to workers, we must encode them as something that can be shipped...
  default['master']['env'] = <<-'EOH'.gsub(/^ {2}/, '')
    lambda{| node | Chef::Node::ImmutableMash.new({
      "JAVA_HOME"          => node['java']['java_home'], # we get the jre if we don't do this
      "JAVA_OPTS"          => node['jenkinsEnv']['JAVA_OPTS'],
      "ANT_OPTS"           => node['jenkinsEnv']['ANT_OPTS'],
      "MAVEN_OPTS"         => node['jenkinsEnv']['MAVEN_OPTS'],
      "prRepoUrl"          => node['repos']['private']['pr-snap'],
      "releaseTempRepoUrl" => node['repos']['private']['release-temp']
    })}
    EOH

  ## PLUGIN
  default['master']['ec2-start-stop']['url'] = 'https://dl.dropboxusercontent.com/u/12862572/ec2-start-stop.hpi'

  # SCABOT
  default['scabot']['jenkins']['user']     = "scala-jenkins"
  default['scabot']['github']['repo_user'] = "scala"
end
