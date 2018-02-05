#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-auth-github
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

apiVault = chef_vault_item("master", "github-api")

# This adds Github oAuth security. (login with your github id.)
