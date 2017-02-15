name             'scala-jenkins-infra'
maintainer       'Lightbend, Inc.'
maintainer_email 'adriaan@lightbend.com'
license          'All rights reserved'
description      'Installs/Configures the Scala Jenkins infrastructure'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.5.0'

# for chef_vault_item, which allows loading from plain databags when developing with vagrant
depends 'chef-vault'

depends 'magic_shell'

depends 'chef-client'
depends 'cron'

depends 'aws'

depends 'ebs'

depends 'windows'
depends 'chocolatey'

depends 'java'
depends 'jenkins'

depends 'artifactory'

depends 'git'
depends 'git_user'

depends 'sbt-extras'

depends 'runit', '~> 1.7'

depends 'nodejs'

