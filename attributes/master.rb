default['master']['auth']             = 'github'
default['master']['github']['webUri'] = 'https://github.com/'
default['master']['github']['apiUri'] = 'https://api.github.com'

default['master']['github']['adminUserNames']                  = 'adriaanm,chef'
default['master']['github']['organizationNames']               = 'scala'
default['master']['github']['useRepositoryPermissions']        = 'true'
default['master']['github']['allowAnonymousReadPermission']    = 'true'
default['master']['github']['authenticatedUserReadPermission'] = 'true'

default['master']['github']['allowGithubWebHookPermission'] = 'true'
default['master']['github']['allowCcTrayPermission']        = 'false'

default['master']['github']['authenticatedUserCreateJobPermission'] = 'false'


# There is a bug in the latest Jenkins that breaks the api/ssh key auth.
# Also you can not pin packages using apt/yum with Jenkins repo
# So we opt for the war install and pin to 1.555
# * https://issues.jenkins-ci.org/browse/JENKINS-22346
# * https://github.com/opscode-cookbooks/jenkins/issues/170
override['jenkins']['master']['install_method'] = 'war'
override['jenkins']['master']['version']        = '1.555'
override['jenkins']['master']['checksum']       = '31f5c2a3f7e843f7051253d640f07f7c24df5e9ec271de21e92dac0d7ca19431'
