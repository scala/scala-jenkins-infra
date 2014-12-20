require 'json'
require 'net/ssh'

key = OpenSSL::PKey::RSA.new(4096)
puts JSON.generate({"private_key" => key.to_pem, "public_key"  => "#{key.ssh_type} #{[key.to_blob].pack('m0')}"})
