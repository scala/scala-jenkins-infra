name             'scala-jenkins-infra'
maintainer       'Typesafe, Inc.'
maintainer_email 'adriaan@typesafe.com'
license          'All rights reserved'
description      'Installs/Configures the Scala Jenkins infrastructure'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends 'chef-client'
depends 'cron'

depends 'aws'

depends 'windows'

depends 'java'
depends 'jenkins'

depends 'git'
depends 'git_user'

# TODO remove chef-sbt dependency, but not sure sbt-extras supports windows
depends 'chef-sbt'
depends 'sbt-extras'
