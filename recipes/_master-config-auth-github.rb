#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-auth-github
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

require "chef-vault"

apiVault = ChefVault::Item.load("master", "github-api")

# This adds Github oAuth security. (login with your github id.)
# TODO: build bot will need support oauth
jenkins_script 'add_gh_authentication' do
  command <<-EOH.gsub(/^ {4}/, '')
    import jenkins.model.Jenkins
    import org.jenkinsci.plugins.*

    def githubRealm = new GithubSecurityRealm(
      '#{node['master']['github']['webUri']}',
      '#{node['master']['github']['apiUri']}',
      '#{apiVault['client-id']}',
      '#{apiVault['client-secret']}')

    def githubStrategy = new GithubAuthorizationStrategy(
      '#{node['master']['github']['adminUserNames']}',
      #{node['master']['github']['authenticatedUserReadPermission']},
      #{node['master']['github']['useRepositoryPermissions']},
      #{node['master']['github']['authenticatedUserCreateJobPermission']},
      '#{node['master']['github']['organizationNames']}',
      #{node['master']['github']['allowGithubWebHookPermission']},
      #{node['master']['github']['allowCcTrayPermission']},
      #{node['master']['github']['allowAnonymousReadPermission']})

    Jenkins.instance.setSecurityRealm(githubRealm)
    Jenkins.instance.setAuthorizationStrategy(githubStrategy)
    Jenkins.instance.save()
  EOH
end
