# handle modalias settings from modinfo output
# parses the device ID string to Vendor and Device parts
class ModAlias
  attr_reader :vid, :did

  # '*' in modinfo alias means
  # all device IDs
  def validate_id(id)
    if id.nil? || id == '*'
      id = :ffffffff
    end

    id
  end

  private :validate_id

  # initialize the object from PCI modalias string
  def initialize(pci_alias)
    if pci_alias.match /^pci:v([^d]*)d.*$/
      @vid = $1
    end

    if pci_alias.match /^pci:v[^d]*d([^s]*)s.*$/
      @did = $1
    end

    @vid = validate_id(@vid)
    @did = validate_id(@did)
  end
end

# class for storing Alsa module parameter info
# from modinfo output
class AlsaModuleParam
  attr_reader :name, :description, :type

  def initialize(name, desc, type)
    @name = name
    @description = desc
    @type = type
  end
end

# class for handling kernel driver info
# (description, device aliases,...)
class AlsaModule
  attr_reader :mod_path

  # initialize the object with kernel module path
  def initialize(path)
    @mod_path = path
  end

  #  get just the module name from the driver path
  def name
    @mod_path.match /\/([^\/]*).ko$/
    return $1
  end

  # read the description from the driver
  def description
    `/sbin/modinfo -F description #{@mod_path}`.strip
  end

  # read the device module aliases
  def modaliases
    lst = `/sbin/modinfo -F alias #{@mod_path}`.split("\n")
    ret = []

    lst.each do |a|
      ret << ModAlias.new(a) if a.match /^pci:/
    end

    extra_ids = eval(File.read(File.join(File.dirname(__FILE__), 'data_extra_ids.rb')))
    extra_ids.each do |id|
      ret << ModAlias.new("pci:v#{id[1]}d#{id[2]}sv*sd*") if id[0] == name
    end

    ret
  end

  #  read the module parameters
  def params
    lst = `/sbin/modinfo #{@mod_path}`.split("\n")
    ret = []

    lst.each do |a|
      if a.match /^parm:[ \t]*([^:]*):(.*)/
        nm = $1.strip
        data = $2.strip
        type = :none

        if nm != 'enable' && nm != 'id' && nm != 'index'
          if data.match /(.*)\(.*(int|long|bool|charp).*\)$/
            data = $1.strip
            type = $2.to_sym
          end

          ret << AlsaModuleParam.new(nm, data, type)
        end
      end
    end

    ret
  end

  # find all sound drivers below the given path
  def self.find_all(path)
    ret = []
    lst = `find #{path} -type f -name 'snd-*.ko'`.split("\n").sort{|p1, p2| 
	p1.split('/').last <=> p2.split('/').last
    }

    lst.each do |m|
      ret << AlsaModule.new(m)
    end

    ret
  end
end
