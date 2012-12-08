sourcebuild_simple "wget" do
  version    "1.14"
  source_url "http://ftp.gnu.org/gnu/wget/wget-1.14.tar.gz"
  creates    "/usr/local/bin/wget"
end
