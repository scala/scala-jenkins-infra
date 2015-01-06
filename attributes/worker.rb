case node["platform_family"]
when "windows"
  # configure windows-specific recipes (attributes not node-specific!)
  override['java']['windows']['package_name'] = 'Java(TM) SE Development Kit 6 (64-bit)'
  override['java']['windows']['url']          = 'https://dl.dropboxusercontent.com/u/12862572/jdk-6u45-windows-x64.exe'
  override['java']['windows']['checksum']     = '345059d5bc64275c1d8fdc03625d69c16d0c8730be1c152247f5f96d00b21b00'
  override['java']['java_home']               = 'C:\java\jdk-1.6' # must specify java_home on windows (issues with installer on reinstall if it's in program files)

  default['java']['javacVersion']            = "javac 1.6.0_45"  # we don't install if javac -version returns this string

  override['sbt']['script_name']   = 'sbt.bat'
  override['sbt']['launcher_path'] = 'C:\sbt'
  override['sbt']['bin_path']      = 'C:\sbt'

  # this zip was reworked to have the binaries under the `bin/` directory, which is what sbt-nativepackager expects
  override['wix']['home']     = 'C:\WIX'
  override['wix']['url']      = 'https://dl.dropboxusercontent.com/u/12862572/wix39-binaries.zip'
  override['wix']['checksum'] = '1f509e61462e49918bf7932e42a78bbc60e6125b712995f55279a6d721f00602'

  override['cygwin']['home']             = 'c:\cygwin'
  override['cygwin']['base']['url']      = "https://dl.dropboxusercontent.com/u/12862572/cygwin-base-x64.zip"
  override['cygwin']['base']['checksum'] = "7f319644c0737895e6cea807087e4e79d117049b8f6ac3087ad3b03724653db9"
  override['cygwin']['installer']['url'] = "http://cygwin.com/setup-x86_64.exe"

  # TODO: also derive PATH variable from attributes
  ## Git is installed to Program Files (x86) on 64-bit machines and
  ## 'Program Files' on 32-bit machines
  ## PROGRAM_FILES = ENV['ProgramFiles(x86)'] || ENV['ProgramFiles']
  ## GIT_PATH      = "#{ PROGRAM_FILES }\\Git\\Cmd"

  default["jenkinsHomes"]['C:\jenkins']["executors"]   = 2
  default["jenkinsHomes"]['C:\jenkins']["workerName"]  = "windows"
  default["jenkinsHomes"]['C:\jenkins']["labels"]      = ["windows"]
  default["jenkinsHomes"]['C:\jenkins']["publish"]     = false
  # can't marshall closures, but they sometimes need to be shipped, so encode as string, closing over `node`
  default["jenkinsHomes"]['C:\jenkins']["env"]         = <<-'EOH'.gsub(/^ {4}/, '')
    lambda{| node | Chef::Node::ImmutableMash.new({
      "PATH"         => "/bin:/usr/bin:/cygdrive/c/java/jdk-1.6/bin:/cygdrive/c/Program Files (x86)/Git/Cmd", # TODO express in terms of attributes
      "sbtLauncher"  => "#{node['sbt']['launcher_path']}\\sbt-launch.jar", # from chef-sbt cookbook
      "WIX"          => node['wix']['home'],
      "JAVA_HOME"    => node['java']['java_home']
    })}
    EOH

when "debian", "rhel"
  override['java']['jdk_version']    = '6'
  override['java']['install_flavor'] = 'oracle' # partest's javap tests fail on openjdk...
  override['java']['oracle']['accept_oracle_download_terms'] = true

  publisher = (node.name =~ /.*-publish$/) != nil # TODO: use tag?

  default["jenkinsHomes"]["/home/jenkins"]["executors"]   = 3
  default["jenkinsHomes"]["/home/jenkins"]["workerName"]  = node.name
  default["jenkinsHomes"]["/home/jenkins"]["labels"]      = ["linux", publisher ? "publish": "public"]
  default["jenkinsHomes"]["/home/jenkins"]["jenkinsUser"] = "jenkins"
  default["jenkinsHomes"]["/home/jenkins"]["publish"]     = publisher


  # can't marshall closures, and this one needs to be shipped from worker to master (note: sshCharaArgs only use on publisher, but doesn't contain any private date, so not bothering)
  default["jenkinsHomes"]["/home/jenkins"]["env"]         = <<-'EOH'.gsub(/^ {4}/, '')
    lambda{| node | Chef::Node::ImmutableMash.new({
      "sshCharaArgs" => '("scalatest@chara.epfl.ch" "-i" "/home/jenkins/.ssh/for_chara")',
      "sbtLauncher"  => File.join(node['sbt']['launcher_path'], "sbt-launch.jar"), # from chef-sbt cookbook
      "sbtCmd"       => File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']), # sbt-extras
      "JAVA_HOME"    => node['java']['java_home'] # we get the jre if we don't do this
    })}
    EOH


  # end
else
  Chef::Log.warn("Unknown worker family: #{node["platform_family"]}")
end
