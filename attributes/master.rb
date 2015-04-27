scalaCiHost = "scala-ci.typesafe.com"
scalaCiPort = 443

# JENKINS WORKER CONFIG
default['repos']['private']['realm']        = "Artifactory Realm"
default['repos']['private']['host']         = "private-repo.typesafe.com"
default['repos']['private']['pr-snap']      = "http://private-repo.typesafe.com/typesafe/scala-pr-validation-snapshots/"
default['repos']['private']['release-temp'] = "http://private-repo.typesafe.com/typesafe/scala-release-temp/"
default['s3']['downloads']['host'] = "downloads.typesafe.com.s3.amazonaws.com"

if node.name == "jenkins-master"
  # JAVA
  default['java']['jdk_version']    = '7'
  default['java']['install_flavor'] = 'openjdk'

  # JENKINS
  override['jenkins']['master']['install_method'] = 'war'
  override['jenkins']['master']['listen_address'] = '127.0.0.1' # external traffic must go through nginx
  override['jenkins']['master']['user']           = 'jenkins'
  override['jenkins']['master']['group']          = 'jenkins'
  override['jenkins']['master']['jvm_options']    = '-server -Xmx4G -XX:MaxPermSize=512M -XX:+HeapDumpOnOutOfMemoryError' # -Dfile.encoding=UTF-8

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
