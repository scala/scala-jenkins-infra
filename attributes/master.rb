override['jenkins']['master']['install_method'] = 'war'
override['jenkins']['master']['listen_address'] = '127.0.0.1' # external traffic must go through nginx
override['jenkins']['master']['user'] = 'jenkins'
override['jenkins']['master']['group'] = 'jenkins'

# To pin the jenkins version, must also override override['jenkins']['master']['source'] !!!
# override['jenkins']['master']['version']  = '1.555'
# override['jenkins']['master']['source']   = "#{node['jenkins']['master']['mirror']}/war/#{node['jenkins']['master']['version']}/jenkins.war"
# override['jenkins']['master']['checksum'] = '31f5c2a3f7e843f7051253d640f07f7c24df5e9ec271de21e92dac0d7ca19431'

default['master']['github']['webUri']                               = 'https://github.com/'
default['master']['github']['apiUri']                               = 'https://api.github.com'
default['master']['github']['adminUserNames']                       = 'adriaanm,chef,scala-jenkins'
default['master']['github']['organizationNames']                    = 'scala'
default['master']['github']['useRepositoryPermissions']             = 'true'
default['master']['github']['allowAnonymousReadPermission']         = 'true'
default['master']['github']['authenticatedUserReadPermission']      = 'true'
default['master']['github']['allowGithubWebHookPermission']         = 'true'
default['master']['github']['allowCcTrayPermission']                = 'false'
default['master']['github']['authenticatedUserCreateJobPermission'] = 'false'

default['master']['adminAddress'] = "adriaan@typesafe.com"
default['master']['jenkinsUrl']   = "https://scala-ci.typesafe.com/"
default['master']['jenkins']['notifyUrl'] = "http://scala-ci.typesafe.com:8888/jenkins"

default['master']['env'] = <<-'EOH'.gsub(/^ {2}/, '')
  lambda{| node | Chef::Node::ImmutableMash.new({
    "JAVA_OPTS"  => "-server -XX:+AggressiveOpts -XX:+UseParNewGC -Xmx2G -Xss1M -XX:MaxPermSize=512M -XX:ReservedCodeCacheSize=128M -Dpartest.threads=4",
    "ANT_OPTS"   => "-server -XX:+AggressiveOpts -XX:+UseParNewGC -Xmx2G -Xss1M -XX:MaxPermSize=512M -XX:ReservedCodeCacheSize=128M -Dpartest.threads=4",
    "MAVEN_OPTS" => "-server -XX:+AggressiveOpts -XX:+UseParNewGC -Xmx2G -Xss1M -XX:MaxPermSize=512M -XX:ReservedCodeCacheSize=128M",
    "prRepoUrl"  => "http://private-repo.typesafe.com/typesafe/scala-pr-validation-snapshots/"
  })}
  EOH

default['master']['ec2-start-stop']['url'] = 'https://dl.dropboxusercontent.com/u/12862572/ec2-start-stop.hpi'


default['scabot']['jenkins']['user']     = "scala-jenkins"
default['scabot']['github']['repo_user'] = "scala"
