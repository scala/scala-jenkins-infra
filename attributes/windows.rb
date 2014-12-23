if platform_family?("windows")
  # configure windows-specific recipes (attributes not node-specific!)
  override['java']['windows']['package_name'] = 'Java(TM) SE Development Kit 6 (64-bit)'
  override['java']['windows']['url']          = 'https://dl.dropboxusercontent.com/u/12862572/jdk-6u45-windows-x64.exe'
  override['java']['windows']['checksum']     = '345059d5bc64275c1d8fdc03625d69c16d0c8730be1c152247f5f96d00b21b00'

  # must specify java_home on windows (issues with installer on reinstall if it's in program files)
  override['java']['java_home'] = 'C:\java\jdk-1.6'

  override['sbt']['script_name']   = 'sbt.bat'
  override['sbt']['launcher_path'] = 'C:\sbt'
  override['sbt']['bin_path']      = 'C:\sbt'

  override['wix']['home']     = 'C:\WIX'
  # this zip was rework to have the binaries under the `bin/` directory, which is what sbt-nativepackage expects
  override['wix']['url']      = 'https://dl.dropboxusercontent.com/u/12862572/wix39-binaries.zip'
  override['wix']['checksum'] = '1f509e61462e49918bf7932e42a78bbc60e6125b712995f55279a6d721f00602'


  override['cygwin']['home']             = 'c:\cygwin'
  override['cygwin']['base']['url']      = "https://dl.dropboxusercontent.com/u/12862572/cygwin-base-x64.zip"
  override['cygwin']['base']['checksum'] = "7f319644c0737895e6cea807087e4e79d117049b8f6ac3087ad3b03724653db9"
  override['cygwin']['installer']['url'] = "http://cygwin.com/setup-x86_64.exe"

  # TODO: remove copy/paste
  override["worker"]["env"]["sbtLauncher"] = 'C:\sbt\sbt-launch.jar' # from chef-sbt cookbook
  override["worker"]["env"]["WIX"]         = 'C:\WIX' # wix
  override["worker"]["env"]["PATH"]        = "/bin:/usr/bin:/cygdrive/c/java/jdk-1.6/bin:/cygdrive/c/Program Files (x86)/Git/Cmd" # java, git cookbooks
end