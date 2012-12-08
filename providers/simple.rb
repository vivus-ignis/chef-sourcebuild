require 'fileutils'

def file_ext(filename)
  filename.scan(/\.(zip|tar|gz|xz|bz2)/).join('.')
end

def get_sources(src_url, name, version)

  Chef::Log.debug("// sourcebuild_simple > get_sources : src_url = #{src_url}")
  Chef::Log.debug("// sourcebuild_simple > get_sources : name    = #{name}")
  Chef::Log.debug("// sourcebuild_simple > get_sources : version = #{version}")

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
  Chef::Log.debug("// sourcebuild_simple > unpack_sources : archive = #{archive}")

  f_ext = file_ext archive

  extract_command = case f_ext
                    when "zip"
                      "unzip"
                    when "tar.gz"
                      "tar xzf"
                    when "tar.bz2"
                      "tar xjf"
                    end

  unless extract_command
    Chef::Log.fatal("Cannot determine extract command for extension #{f_ext}")
    raise
  end

  Chef::Log.debug("// sourcebuild_simple > unpack_sources : extract_command = #{extract_command}")

  FileUtils.mkdir_p "#{Chef::Config[:file_cache_path]}/sourcebuild"

  tmpdir = `mktemp -d #{Chef::Config[:file_cache_path]}/sourcebuild/src.XXXXXX`.chomp
  Chef::Log.debug("// sourcebuild_simple > unpack_sources : tmpdir = #{tmpdir}")

  FileUtils.cp(#{archive}, #{tmpdir})

  system "cd #{tmpdir}; #{extract_command} #{archive}"

  unless $?.exitstatus == 0
    Chef::Log.fatal("Extract command failed")
    raise
  end

  FileUtils.rm "#{tmpdir}/#{::File.basename archive}"

  srcdir = nil

  ::Dir.glob("#{tmpdir}/*").each do |f|
    Chef::Log.debug("// sourcebuild_simple > unpack_sources : glob block : f = #{f}")
    if ::File.directory? f
      srcdir = f
      break
    end
  end

  Chef::Log.debug("// sourcebuild_simple > unpack_sources : source dir detected = #{srcdir}")

  unless srcdir
    Chef::Log.fatal("Cannot determine source directory, listing: #{::Dir.entries tmpdir}")
    raise
  end

  srcdir
end

def compile_sources(dir, install_prefix)
  Chef::Log.debug("// sourcebuild_simple > compile_sources : dir            = #{dir}")
  Chef::Log.debug("// sourcebuild_simple > compile_sources : install_prefix = #{install_prefix}")

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
