sourcebuild_simple "nginx" do
  version    "1.3.9"
  source_url "http://nginx.org/download/nginx-1.3.9.tar.gz"
  creates    "/usr/local/sbin/nginx"
end
