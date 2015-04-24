name             'scala-jenkins-infra'
maintainer       'Typesafe, Inc.'
maintainer_email 'adriaan@typesafe.com'
license          'All rights reserved'
description      'Installs/Configures the Scala Jenkins infrastructure'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.2.0'

# for chef_vault_item, which allows loading from plain databags when developing with vagrant
depends 'chef-vault'

depends 'magic_shell'

depends 'chef-client'
depends 'cron'

depends 'aws'

depends 'ebs'

depends 'windows'

depends 'java'
depends 'jenkins'

depends 'git'
depends 'git_user'

# TODO remove chef-sbt dependency, but not sure sbt-extras supports windows
depends 'chef-sbt'
depends 'sbt-extras'

depends 'runit', '~> 1.5'