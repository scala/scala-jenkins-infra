# configure windows-specific recipes (attributes not node-specific!)
override['java']['windows']['package_name'] = 'Java(TM) SE Development Kit 6 (64-bit)'
override['java']['windows']['url']          = 'https://dl.dropboxusercontent.com/u/12862572/jdk-6u45-windows-x64.exe'
override['java']['windows']['checksum']     = '345059d5bc64275c1d8fdc03625d69c16d0c8730be1c152247f5f96d00b21b00'

# must specify java_home -- it will be deleted so we don't hit the broken reinstall functionality in the java installer
override['java']['java_home'] = 'C:/java/jdk-1.6' if Chef::Platform.windows?


# the url must end in a name that's windows-friendly -- good idea to cache it in case they change the download anyway
override['wix']['url']                  = 'https://dl.dropboxusercontent.com/u/12862572/wix39-binaries.zip'
override['wix']['checksum']             = '91c1b77bb6058bf25b5577be151b4adca0d174db60dbf89d6ff94528f650ec6c'
