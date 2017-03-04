default['sbt']['version'] = "0.13.12"

workerJavaOpts = "-Dfile.encoding=UTF-8 -server -XX:+AggressiveOpts -XX:+UseParNewGC -Xmx2G -Xss1M -XX:MaxPermSize=512M -XX:ReservedCodeCacheSize=128M -Dpartest.threads=4"

if (node.name =~ /.*-worker-.*/) != nil
  case node["platform_family"]
  when "windows"
    jenkinsHome = 'y:\jenkins'
    
    override['sbt']['launcher_path'] = 'C:\sbt\sbt-launch.jar'
    override['wix']['home']          = 'C:\Program Files (x86)\WiX Toolset v3.10'
    override['cygwin']['home']       = 'C:\tools\cygwin'
    jvmHome                          = '/Program Files/Java/jdk1.8.0_121'
    gitBin                           = '/cygdrive/c/Program Files/Git/Cmd'
    chocoBin                         = '/cygdrive/c/ProgramData/chocolatey/bin'
    jenkinsTmp                       = 'y:/jenkins/tmp'

    override['java']['java_home']    = "C:#{jvmHome.gsub(/\//,'\\')}"
    jvmBin                           = "/cygdrive/c#{jvmHome}/bin"
  
    # deal with weirdness in java using registry keys to find the homedir (c:\users\jenkins), instead of the cygin home (/home/jenkins or y:\jenkins)
    jvmDirOptions = "-Duser.home=#{jenkinsHome.gsub(/\\/,'/')} -Djava.io.tmpdir=#{jenkinsTmp}" # jenkins doesn't quote properly

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
    default["jenkinsHomes"][jenkinsHome]["jvm_options"] = jvmDirOptions
    default["jenkinsHomes"][jenkinsHome]["java_path"]   = "\"C:#{jvmHome}/bin/java\"" # note the double quoting
    default["jenkinsHomes"][jenkinsHome]["labels"]      = ["windows", publisher ? "publish": "public"]
    default["jenkinsHomes"][jenkinsHome]["publish"]     = publisher

    default["jenkinsHomes"][jenkinsHome]["usage_mode"]  = 'exclusive' # windows is a speciality node, don't run jobs here unless they asked for a `windows` node

    default["jenkinsHomes"][jenkinsHome]["in_demand_delay"] = 1  # if builds are in queue for even one minute, launch this worker
    default["jenkinsHomes"][jenkinsHome]["idle_delay"]      = 15 # take worker off-line after 15 min of idling (we're charged by the hour, so no rush)

 
    default["jenkinsHomes"][jenkinsHome]["env"]['JAVA_HOME']          = node['java']['java_home'] # we get the jre if we don't do this
    default["jenkinsHomes"][jenkinsHome]["env"]['JAVA_OPTS']          = "#{workerJavaOpts} #{jvmDirOptions}"
    default["jenkinsHomes"][jenkinsHome]["env"]['ANT_OPTS']           = "#{workerJavaOpts} #{jvmDirOptions}"
    default["jenkinsHomes"][jenkinsHome]["env"]['MAVEN_OPTS']         = "#{workerJavaOpts} #{jvmDirOptions}"
    default["jenkinsHomes"][jenkinsHome]["env"]['prRepoUrl']          = node['repos']['private']['pr-snap']
    default["jenkinsHomes"][jenkinsHome]["env"]['integrationRepoUrl'] = node['repos']['private']['integration']
    default["jenkinsHomes"][jenkinsHome]["env"]['PATH']               = "/bin:/usr/bin:#{jvmBin}:#{gitBin}:#{chocoBin}"
    default["jenkinsHomes"][jenkinsHome]["env"]['sbtLauncher']        = node['sbt']['launcher_path']
    default["jenkinsHomes"][jenkinsHome]["env"]['WIX']                = node['wix']['home']
    default["jenkinsHomes"][jenkinsHome]["env"]['TMP']                = jenkinsTmp
    default["jenkinsHomes"][jenkinsHome]["env"]['_JAVA_OPTIONS']      = jvmDirOptions # no other way to do this... sbt boot will fail pretty weirdly if it can't write to $HOME/.sbt and $TMP/...
    default["jenkinsHomes"][jenkinsHome]["env"]['SHELLOPTS']          = "igncr" # ignore line-ending issues in shell scripts

  else
    jenkinsHome="/home/jenkins"
    # If node name contains "-publish", configure it with necessary secrets/package to roll & publish a release
    publisher = (node.name =~ /.*-publish.*/) != nil # TODO: use tag?
    lightWorker = publisher  # TODO: better heuristic...

    if !lightWorker
      default['ebs']['volumes']['none']['size']      = 16
      default['ebs']['volumes']['none']['dev']       = "/dev/sdp"
      default['ebs']['volumes']['none']['fstype']    = "swap"
      default['ebs']['volumes']['none']['mountopts'] = "sw"
    end

    override['sbt']['launcher_path'] = '/usr/local/lib/share/sbt-launch.jar'

    default['graphviz']['url']      = 'https://dl.dropboxusercontent.com/u/12862572/graphviz_2.28.0-1_amd64.deb'
    default['graphviz']['checksum'] = '76236edc36d5906b93f35e83f8f19a2045318852d3f826e920f189431967c081'
    default['graphviz']['version']  = '2.28.0-1'

    default['ebs']['volumes'][jenkinsHome]['size']      = lightWorker ? 50 : 100 # size of the volume correlates to speed (in IOPS)
    default['ebs']['volumes'][jenkinsHome]['dev']       = "/dev/sdj"
    default['ebs']['volumes'][jenkinsHome]['fstype']    = "ext4"
    default['ebs']['volumes'][jenkinsHome]['user']      = "jenkins"
    default['ebs']['volumes'][jenkinsHome]['mountopts'] = 'noatime'

    default["jenkinsHomes"][jenkinsHome]["workerName"]      = node.name
    default["jenkinsHomes"][jenkinsHome]["jenkinsUser"]     = "jenkins"
    default["jenkinsHomes"][jenkinsHome]["publish"]         = publisher
    default["jenkinsHomes"][jenkinsHome]["in_demand_delay"] = 0  # launch worker immediately
    default["jenkinsHomes"][jenkinsHome]["idle_delay"]      = 20 # take worker off-line after 20 min of idling (we're charged by the hour, so no rush)
                            jenkinsHome
    default["jenkinsHomes"][jenkinsHome]["executors"]  = lightWorker ? 1 : 3
    default["jenkinsHomes"][jenkinsHome]["usage_mode"] = publisher ? "exclusive" : "normal"
    default["jenkinsHomes"][jenkinsHome]["labels"]     = ["linux", publisher ? "publish": "public"]

    default["jenkinsHomes"][jenkinsHome]["env"]['JAVA_OPTS']          = workerJavaOpts
    default["jenkinsHomes"][jenkinsHome]["env"]['ANT_OPTS']           = workerJavaOpts
    default["jenkinsHomes"][jenkinsHome]["env"]['MAVEN_OPTS']         = workerJavaOpts
    default["jenkinsHomes"][jenkinsHome]["env"]['prRepoUrl']          = node['repos']['private']['pr-snap']
    default["jenkinsHomes"][jenkinsHome]["env"]['integrationRepoUrl'] = node['repos']['private']['integration']
    default["jenkinsHomes"][jenkinsHome]["env"]['sbtLauncher']        = node['sbt']['launcher_path']
    default["jenkinsHomes"][jenkinsHome]["env"]['sshCharaArgs']       = '("scalatest@chara.epfl.ch" "-i" "/home/jenkins/.ssh/for_chara")'
    default["jenkinsHomes"][jenkinsHome]["env"]['sbtCmd']             = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras

  end
end
