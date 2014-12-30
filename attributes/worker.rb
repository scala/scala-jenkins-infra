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


  # TODO: remove copy/paste, use jenkinsHomes structure as on linux
  default["worker"]["env"]["sbtLauncher"] = 'C:\sbt\sbt-launch.jar' # from chef-sbt cookbook
  default["worker"]["env"]["WIX"]         = 'C:\WIX' # wix
  default["worker"]["env"]["PATH"]        = "/bin:/usr/bin:/cygdrive/c/java/jdk-1.6/bin:/cygdrive/c/Program Files (x86)/Git/Cmd" # java, git cookbooks
  default["worker"]["env"]["JAVA_HOME"]   = node['java']['java_home']
when "debian", "rhel"
  override['java']['jdk_version']    = '6'
  override['java']['install_flavor'] = 'oracle' # partest's javap tests fail on openjdk...
  override['java']['oracle']['accept_oracle_download_terms'] = true

  # TODO: factor out duplication

  default["jenkinsHomes"]["/home/jenkins-pub"]["env"]["sbtLauncher"] = File.join(node['sbt']['launcher_path'], "sbt-launch.jar") # from chef-sbt cookbook
  default["jenkinsHomes"]["/home/jenkins-pub"]["env"]["sbtCmd"]      = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
  default["jenkinsHomes"]["/home/jenkins-pub"]["env"]["JAVA_HOME"]   = node['java']['java_home'] # we get the jre if we don't do this
  default["jenkinsHomes"]["/home/jenkins-pub"]["executors"]          = 4
  default["jenkinsHomes"]["/home/jenkins-pub"]["workerName"]         = "builder-ubuntu-pub"
  default["jenkinsHomes"]["/home/jenkins-pub"]["labels"]             = ["linux"]
  default["jenkinsHomes"]["/home/jenkins-pub"]["jenkinsUser"]        = "jenkins-pub"
  default["jenkinsHomes"]["/home/jenkins-pub"]["publish"]            = false

  # TODO: if node has tag "publish"
  # if node.tags ...
    default["jenkinsHomes"]["/home/jenkins-priv"]["env"]["sbtLauncher"]  = File.join(node['sbt']['launcher_path'], "sbt-launch.jar") # from chef-sbt cookbook
    default["jenkinsHomes"]["/home/jenkins-priv"]["env"]["sbtCmd"]       = File.join(node['sbt-extras']['setup_dir'], node['sbt-extras']['script_name']) # sbt-extras
    default["jenkinsHomes"]["/home/jenkins-priv"]["env"]["JAVA_HOME"]    = node['java']['java_home'] # we get the jre if we don't do this
    default["jenkinsHomes"]["/home/jenkins-priv"]["env"]["sshCharaArgs"] = "(\"scalatest@chara.epfl.ch\" \"-i\" \"/home/jenkins-priv/.ssh/for_chara\")"
    default["jenkinsHomes"]["/home/jenkins-priv"]["executors"]           = 2
    default["jenkinsHomes"]["/home/jenkins-priv"]["workerName"]          = "builder-ubuntu-priv"
    default["jenkinsHomes"]["/home/jenkins-priv"]["labels"]              = ["linux", "publish"]
    default["jenkinsHomes"]["/home/jenkins-priv"]["jenkinsUser"]         = "jenkins-priv"
    default["jenkinsHomes"]["/home/jenkins-priv"]["publish"]             = true
  # end
end
