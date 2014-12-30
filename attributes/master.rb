override['jenkins']['master']['install_method'] = 'war'

# To pin the jenkins version, must also override override['jenkins']['master']['source'] !!!
# override['jenkins']['master']['version']  = '1.555'
# override['jenkins']['master']['source']   = "#{node['jenkins']['master']['mirror']}/war/#{node['jenkins']['master']['version']}/jenkins.war"
# override['jenkins']['master']['checksum'] = '31f5c2a3f7e843f7051253d640f07f7c24df5e9ec271de21e92dac0d7ca19431'

default['master']['github']['webUri']                               = 'https://github.com/'
default['master']['github']['apiUri']                               = 'https://api.github.com'
default['master']['github']['adminUserNames']                       = 'adriaanm,chef'
default['master']['github']['organizationNames']                    = 'scala'
default['master']['github']['useRepositoryPermissions']             = 'true'
default['master']['github']['allowAnonymousReadPermission']         = 'true'
default['master']['github']['authenticatedUserReadPermission']      = 'true'
default['master']['github']['allowGithubWebHookPermission']         = 'true'
default['master']['github']['allowCcTrayPermission']                = 'false'
default['master']['github']['authenticatedUserCreateJobPermission'] = 'false'

default['master']['adminAddress'] = "adriaan@typesafe.com"
default['master']['jenkinsUrl']   = "http://scala-ci.typesafe.com/"


default['master']['env'] = <<-'EOH'.gsub(/^ {2}/, '')
  lambda{| node | Chef::Node::ImmutableMash.new({
    "ANT_OPTS"  => "-Xms1536M -Xmx1536M -Xss1M -XX:MaxPermSize=256M -XX:ReservedCodeCacheSize=128M -XX:+UseParallelGC -Dpartest.threads=4",
    "JAVA_OPTS" => "-Xms1536M -Xmx1536M -Xss1M -XX:MaxPermSize=256M -XX:ReservedCodeCacheSize=128M -XX:+UseParallelGC -Dpartest.threads=4",
    "prRepoUrl" => "http://private-repo.typesafe.com/typesafe/scala-pr-validation-snapshots/"
  })}
  EOH
