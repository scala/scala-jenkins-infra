# See https://docs.chef.io/config_rb_knife.html for more information on knife configuration options

current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "#{ENV.fetch('CHEF_USER', ENV['USER'])}"
client_key               "#{current_dir}/config/#{ENV.fetch('CHEF_USER', ENV['USER'])}.pem"
validation_client_name   "#{ENV['CHEF_ORG']}-validator"
validation_key           "#{current_dir}/config/#{ENV['CHEF_ORG']}-validator.pem"
chef_server_url          "https://api.opscode.com/organizations/#{ENV['CHEF_ORG']}"
cache_type               'BasicFile'
cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["#{current_dir}/cookbooks"]

knife[:aws_credential_file] = "#{ENV['HOME']}/.aws/credentials"
knife[:aws_ssh_key_id]      = "typesafe-scala-aws-#{ENV.fetch('AWS_USER', ENV['USER'])}" # the pem file name without the .pem extension and it has to be located in: ~/.ssh/
knife[:vault_mode]          = 'client'
