if (node.name =~ /.*-worker-.*/) != nil
  case node["platform_family"]
  when "windows"
    # configure windows-specific recipes (attributes not node-specific!)
    override['java']['windows']['package_name'] = 'Java(TM) SE Development Kit 6 (64-bit)'
    override['java']['windows']['url']          = 'https://dl.dropboxusercontent.com/u/12862572/jdk-6u45-windows-x64.exe' # if you change this, must change javacVersion below
    override['java']['windows']['checksum']     = '345059d5bc64275c1d8fdc03625d69c16d0c8730be1c152247f5f96d00b21b00'
    override['java']['java_home']               = 'C:\java\jdk-1.6' # must specify java_home on windows (issues with installer on reinstall if it's in program files)
    default['java']['javacVersion']            = "javac 1.6.0_45"  # we don't install if javac -version returns this string

    override['sbt']['script_name']   = 'sbt.bat'
    override['sbt']['launcher_path'] = 'C:\sbt'
    override['sbt']['bin_path']      = 'C:\sbt'

    # this zip was reworked to have the binaries under the `bin/` directory, which is what sbt-nativepackager expects
    override['wix']['home']     = 'C:\Program Files (x86)\WiX Toolset v3.9'
    override['wix']['url']      = 'http://static.wixtoolset.org/releases/v3.9.421.0/wix39.exe'
    override['wix']['checksum'] = '46eda1dd64bfdfc3cc117e76902d767f1a47a1e40f7b6aad68b32a18b609eb7c'

    override['cygwin']['home']             = 'c:\cygwin'
    override['cygwin']['installer']['url'] = "http://cygwin.com/setup-x86_64.exe"

    # This zip should contain the "#{Chef::Config[:file_cache_path]}/cygwin" directory,
    # after it was manually populated by running "#{Chef::Config[:file_cache_path]}/cygwin-setup.exe",
    # selecting openssh, cygrunsrv in addition to cygwin's base packages.
    # I did not succeed in automating the cygwin installer without having a local cache of the package archives
    override['cygwin']['base']['url']      = "https://dl.dropboxusercontent.com/u/12862572/cygwin-base-x64.zip"
    override['cygwin']['base']['checksum'] = "dab686bc685ba1447240804a47d10f3b146d4b17b6f9fea781ed9bb59c67e664"

    # TODO: also derive PATH variable from attributes
    ## Git is installed to Program Files (x86) on 64-bit machines and
    ## 'Program Files' on 32-bit machines
    ## PROGRAM_FILES = ENV['ProgramFiles(x86)'] || ENV['ProgramFiles']
    ## GIT_PATH      = "#{ PROGRAM_FILES }\\Git\\Cmd"

    jenkinsHome = 'y:\jenkins'
    jenkinsTmp  = 'y:\tmp'

    # If node name contains "-publish", configure it with necessary secrets/package to roll & publish a release
    publisher = (node.name =~ /.*-publish.*/) != nil # TODO: use tag?

    default['ebs']['volumes']['Y']['size']      = 50
    default['ebs']['volumes']['Y']['dev']       = "sdj"
    default['ebs']['volumes']['Y']['disk']      = 'PCIROOT(0)#PCI(1F00)#PCI(1F00)#SCSI(P00T09L00)' # J is the 9th letter in base-0 --> T09(https://technet.microsoft.com/en-us/library/ee851589%28v=ws.10%29.aspx)

    default['ebs']['volumes']['Y']['fstype']    = "ntfs"
    default['ebs']['volumes']['Y']['user']      = "jenkins"
    default['ebs']['volumes']['Y']['mountopts'] = ''

    default["jenkinsHomes"][jenkinsHome]["executors"]   = 2
    default["jenkinsHomes"][jenkinsHome]["workerName"]  = node.name
    default["jenkinsHomes"][jenkinsHome]["jenkinsUser"] = 'jenkins'
    default["jenkinsHomes"][jenkinsHome]["jvm_options"] = "-Duser.home=#{jenkinsHome.gsub(/\\/,'/')} -Djava.io.tmpdir=#{jenkinsTmp.gsub(/\\/,'/')}" # jenkins doesn't quote properly
    default["jenkinsHomes"][jenkinsHome]["labels"]      = ["windows", publisher ? "publish": "public"]
    default["jenkinsHomes"][jenkinsHome]["publish"]     = publisher

    default["jenkinsHomes"][jenkinsHome]["usage_mode"]  = 'exclusive' # windows is a speciality node, don't run jobs here unless they asked for a `windows` node

    default["jenkinsHomes"][jenkinsHome]["in_demand_delay"] = 1  # if builds are in queue for even one minute, launch this worker
    default["jenkinsHomes"][jenkinsHome]["idle_delay"]      = 15 # take worker off-line after 15 min of idling (we're charged by the hour, so no rush)

    default["_jenkinsHome"] = jenkinsHome
    default["_jenkinsTmp"]  = jenkinsTmp

    # Worker-specific env, the rest is defined in master's attribs.
    # This needs to be a closure to get laziness so that we can refer to other attributes, but can't marshall closures,
    # and they sometimes need to be shipped, so encode as string, closing over `node`...
    default["jenkinsHomes"][jenkinsHome]["env"]         = <<-'EOH'.gsub(/^ {4}/, '')
      lambda{| node | Chef::Node::ImmutableMash.new({
        "PATH"          => "/bin:/usr/bin:/cygdrive/c/java/jdk-1.6/bin:/cygdrive/c/Program Files (x86)/Git/Cmd", # TODO express in terms of attributes
        "sbtLauncher"   => "#{node['sbt']['launcher_path']}\\sbt-launch.jar", # from chef-sbt cookbook
        "WIX"           => node['wix']['home'],
        "TMP"           => "#{node['_jenkinsTmp']}",
        "_JAVA_OPTIONS" => "-Duser.home=#{node['_jenkinsHome']}", # no other way to do this... sbt boot will fail pretty weirdly if it can't write to $HOME/.sbt and $TMP/...
        "SHELLOPTS"     => "igncr" # ignore line-ending issues in shell scripts
      })}
      EOH

  else
    # If node name contains "-publish", configure it with necessary secrets/package to roll & publish a release
    publisher = (node.name =~ /.*-publish.*/) != nil # TODO: use tag?
    lightWorker = publisher  # TODO: better heuristic...

    override['java']['jdk_version']    = '6'
    override['java']['install_flavor'] = 'oracle' # partest's javap tests fail on openjdk...
    override['java']['oracle']['accept_oracle_download_terms'] = true
    # must specify java_home explicitly, or java_ark thinks it's installed even if some other version is...
    override['java']['java_home'] = platform_family?('debian') ? '/usr/lib/jvm/java-6-oracle-amd64' : '/usr/lib/jvm/java-1.6.0-oracle.x86_64'

    default['graphviz']['url']      = 'https://dl.dropboxusercontent.com/u/12862572/graphviz_2.28.0-1_amd64.deb'
    default['graphviz']['checksum'] = '76236edc36d5906b93f35e83f8f19a2045318852d3f826e920f189431967c081'
    default['graphviz']['version']  = '2.28.0-1'

    default['ebs']['volumes']['/home/jenkins']['size']      = lightWorker ? 50 : 100 # size of the volume correlates to speed (in IOPS)
    default['ebs']['volumes']['/home/jenkins']['dev']       = "/dev/sdj"
    default['ebs']['volumes']['/home/jenkins']['fstype']    = "ext4"
    default['ebs']['volumes']['/home/jenkins']['user']      = "jenkins"
    default['ebs']['volumes']['/home/jenkins']['mountopts'] = 'noatime'

    default["jenkinsHomes"]["/home/jenkins"]["workerName"]      = node.name
    default["jenkinsHomes"]["/home/jenkins"]["jenkinsUser"]     = "jenkins"
    default["jenkinsHomes"]["/home/jenkins"]["publish"]         = publisher
    default["jenkinsHomes"]["/home/jenkins"]["in_demand_delay"] = 0  # launch worker immediately
    default["jenkinsHomes"]["/home/jenkins"]["idle_delay"]      = 20 # take worker off-line after 20 min of idling (we're charged by the hour, so no rush)

    default["jenkinsHomes"]["/home/jenkins"]["executors"]  = lightWorker ? 2 : 4
    default["jenkinsHomes"]["/home/jenkins"]["usage_mode"] = publisher ? "exclusive" : "normal"
    default["jenkinsHomes"]["/home/jenkins"]["labels"]     = ["linux", publisher ? "publish": "public"]

    # Worker-specific env, the rest is defined in master's attribs.
    # (note: sshCharaArgs only used on publisher, but doesn't contain any private date, so not bothering to split it out)
    # This needs to be a closure to get laziness so that we can refer to other attributes, but can't marshall closures,
    # and they sometimes need to be shipped, so encode as string, closing over `node`...
    default["jenkinsHomes"]["/home/jenkins"]["env"]         = <<-'EOH'.gsub(/^ {4}/, '')
      lambda{| node | Chef::Node::ImmutableMash.new({
        "sshCharaArgs" => '("scalatest@chara.epfl.ch" "-i" "/home/jenkins/.ssh/for_chara")',
        "sbtLauncher"  => File.join(node['sbt']['launcher_path'], "sbt-launch.jar"), # from chef-sbt cookbook
        "sbtCmd"       => File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
      })}
      EOH
  end
end
