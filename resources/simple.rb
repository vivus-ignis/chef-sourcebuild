actions :create, :delete

def initialize(*args)
  super
  @action = :create
end

attribute :name,             :kind_of => String, :name_attribute => true 
attribute :version,          :kind_of => String
attribute :source_url,       :kind_of => String
attribute :creates,          :kind_of => String
attribute :install_prefix,   :kind_of => String, :default => "/usr/local"
