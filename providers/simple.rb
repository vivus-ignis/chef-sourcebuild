def file_ext(filename)
  filename.scan(/\.(zip|tar|gz|xz|bz2)/).join('.')
end

def get_sources(src_url, name, version)

  directory "#{Chef::Config[:file_cache_path]}/sourcebuild/#{name}" do
    recursive true
  end

  f_ext = file_ext( ::File.basename(src_url) )

  Chef::Log.debug("// sourcebuild_simple > get_sources : f_ext = #{f_ext}")

  remote_file src_url do
    path   "#{Chef::Config[:file_cache_path]}/sourcebuild/#{name}/#{name}-#{version}.#{f_ext}"
    source src_url
    mode   0644
    backup false
    
    not_if { ::File.exists? "#{Chef::Config[:file_cache_path]}/sourcebuild/#{name}/#{name}-#{version}.#{f_ext}" }
  end
  
  "#{Chef::Config[:file_cache_path]}/sourcebuild/#{name}/#{name}-#{version}.#{f_ext}"
end

# we do not know how the directory in a source archive named,
# so let's guess by unpacking in empty directory and using glob
def unpack_sources(archive)
  f_ext = file_ext archive

  extract_command = case f_ext
                    when "zip"
                      "unzip"
                    when "tar.gz"
                      "tar xzf"
                    when "tar.bz2"
                      "tar xjf"
                    end

  Chef::Log.debug("// sourcebuild_simple > unpack_sources : extract_command = #{extract_command}")

  directory "#{Chef::Config[:file_cache_path]}/sourcebuild"

  tmpdir = `mktemp -d #{Chef::Config[:file_cache_path]}/sourcebuild/src.XXXXXX`.chomp

  Chef::Log.debug("// sourcebuild_simple > unpack_sources : tmpdir = #{tmpdir}")

  execute "cp #{archive} #{tmpdir}/"

  execute "Unpack #{archive}" do
    cwd     tmpdir
    command "#{extract_command} #{archive}"
  end

  file "#{tmpdir}/#{::File.basename archive}" do
    action :delete
  end

  srcdir = ::Dir.glob("#{tmpdir}/*").each do |f|
    break f if ::File.directory? f
  end

  Chef::Log.debug("// sourcebuild_simple > unpack_sources : source dir detected = #{srcdir}")

  srcdir
end

def compile_sources(dir, install_prefix)
  execute "./configure --prefix=#{install_prefix}" do
    cwd dir
    not_if { ::File.exists? "#{dir}/Makefile" }
  end
  
  execute "make" do
    cwd dir
  end
end

def install(dir)
  execute "make install" do
    cwd dir
  end
end

action :create do

  unless ::File.exists? new_resource.creates
    source_archive = get_sources(new_resource.source_url, new_resource.name, new_resource.version)
    source_dir     = unpack_sources(source_archive)
    compile_sources(source_dir, new_resource.install_prefix)
    install(source_dir)
  end

end
