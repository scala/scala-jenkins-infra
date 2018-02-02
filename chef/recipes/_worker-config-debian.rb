

  directory jenkinsHome do
    owner workerConfig["jenkinsUser"]
#    mode 00755  -- TODO: enable on linux, but NOT on windows, as it causes permissions problems (no idea how to fix)
    action :create
  end

  directory "#{jenkinsHome}/.ssh" do
    owner workerConfig["jenkinsUser"]
#    mode  '700' -- TODO: enable on linux, but NOT on windows, as it causes permissions problems (no idea how to fix)
  end

  # for use by java.io.tmpdir since /tmp may not have enough space
  directory "#{jenkinsHome}/tmp" do
    owner workerConfig["jenkinsUser"]
  end

  file "#{jenkinsHome}/.ssh/authorized_keys" do
    owner workerConfig["jenkinsUser"]
    mode  '600'
    content chef_vault_item("master", "scala-jenkins-keypair")['public_key'] + "\n#{node['authorized_keys']['jenkins']}"
  end

    git_user workerConfig["jenkinsUser"] do
      home        jenkinsHome
      full_name   'Scala Jenkins'
      email       'adriaan@lightbend.com'
    end

node["jenkinsHomes"].each do |jenkinsHome, workerConfig|
  jenkinsUser=workerConfig["jenkinsUser"]

  # TODO: recursive doesn't set owner correctly (???), so list out all dirs explicitly
  ["#{jenkinsHome}/.ssh", "#{jenkinsHome}/.ivy2", "#{jenkinsHome}/.m2", "#{jenkinsHome}/.sbt", "#{jenkinsHome}/.sbt/0.13", "#{jenkinsHome}/.sbt/0.13/plugins/"].each do |dir|
    directory dir do
      user jenkinsUser
    end
  end

  if workerConfig["publish"]
    file "#{jenkinsHome}/.ssh/for_chara" do
      owner jenkinsUser
      mode '600'
      sensitive true
      content chef_vault_item("worker-publish", "chara-keypair")['private_key']
    end

    execute 'accept chara host key' do
      command "ssh -oStrictHostKeyChecking=no scalatest@chara.epfl.ch -i \"#{jenkinsHome}/.ssh/for_chara\" true"
      user jenkinsUser
      #
      # not_if "grep -qs \"#{chef_vault_item("worker-publish", "chara-keypair")['public_key']}\" #{jenkinsHome}/.ssh/known_hosts"
    end

    directory "#{jenkinsHome}/.gnupg" do
      owner workerConfig["jenkinsUser"]
    end

    ["sec", "pub"].each do |kind|
      file "#{jenkinsHome}/.gnupg/#{kind}ring.gpg" do
        owner jenkinsUser
        mode '600'
        sensitive true
        content Base64.decode64(chef_vault_item("worker-publish", "gnupg")["#{kind}ring-base64"])
      end
    end

    privateRepo = chef_vault_item("worker-publish", "private-repo")
    s3Downloads = chef_vault_item("worker-publish", "s3-downloads")
    sonatype    = chef_vault_item("worker-publish", "sonatype")

    { "#{jenkinsHome}/.credentials-private-repo" => "credentials-private-repo.erb",
      "#{jenkinsHome}/.credentials-sonatype"     => "credentials-sonatype.erb",
      "#{jenkinsHome}/.credentials"              => "credentials-private-repo.erb",
      "#{jenkinsHome}/.sonatype-curl"            => "sonatype-curl.erb",
      "#{jenkinsHome}/.s3credentials"            => "s3credentials.erb",
      "#{jenkinsHome}/.s3curl"                   => "s3curl.erb",
      "#{jenkinsHome}/.m2/settings.xml"          => "m2-settings.xml.erb" # TODO: remove pr-scala stuff, use different credentials for private-repo for PR validation and temp release artifacts
    }.each do |target, templ|
      template target do
        source    templ
        user      jenkinsUser
        owner     jenkinsUser
        mode      '600'
        sensitive true

        variables({
          :privateRepo => privateRepo,
          :s3Downloads => s3Downloads,
          :sonatype    => sonatype
        })
        helpers(ScalaJenkinsInfra::JobBlurbs)
      end
    end

    template "#{jenkinsHome}/.sbt/0.13/plugins/gpg.sbt" do
      source "sbt-0.13-plugins-gpg.sbt.erb"
      user jenkinsUser
    end

    # NOTE: graphviz version 2.36.0 (20140111.2315) crashes during scaladoc:
    #       *** Error in `dot': corrupted double-linked list: 0x00000000019648c0 ***
    #       this caused some diagrams not to be rendered...
    #       Same for graphviz version 2.38.0 (20140413.2041):
    #       *** Error in `dot': corrupted double-linked list: 0x000000000196f5f0 ***
    # The old build server was on 2.28.0.... thus:
    #   sudo apt-get install gcc checkinstall libexpat-dev
    #   curl -O http://graphviz.org/pub/graphviz/stable/SOURCES/graphviz-2.28.0.tar.gz
    #   tar xvzf graphviz-2.28.0.tar.gz && cd graphviz-2.28.0/
    #   ./configure && make && sudo checkinstall
    deb = remote_file "#{Chef::Config[:file_cache_path]}/graphviz-#{node['graphviz']['version']}.deb" do
      source   node['graphviz']['url']
      checksum node['graphviz']['checksum']
      notifies :install, "dpkg_package[graphviz]"
    end

    dpkg_package "graphviz" do
      source  deb.path
      version node['graphviz']['version']
      action :nothing # triggered by the corresponding remote_file above
    end

    %w{jq curl zip xz-utils rpm dpkg lintian fakeroot}.each do |pkg|
      package pkg
    end
  else
    privateRepo = chef_vault_item("worker", "private-repo-public-jobs")

    { "#{jenkinsHome}/.m2/settings.xml" => "m2-settings-public-jobs.xml.erb",
      "#{jenkinsHome}/.credentials"     => "credentials-private-repo.erb"
    }.each do |target, templ|
      template target do
        source templ
        user jenkinsUser
        sensitive true

        variables({
          :privateRepo => privateRepo
        })
        helpers(ScalaJenkinsInfra::JobBlurbs)
      end
    end
  end
end
