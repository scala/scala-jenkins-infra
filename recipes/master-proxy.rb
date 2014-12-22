# Set up a reverse proxy to allow jenkins to run on port 80

package "nginx"

template '/etc/nginx/nginx.conf' do
  source 'nginx.conf'
  notifies :reload, "service[nginx]"
end

template '/etc/nginx/conf.d/jenkins.conf' do
  source 'nginx-jenkins.conf'
  notifies :reload, "service[nginx]"
end

service 'nginx' do
  action :start
end
