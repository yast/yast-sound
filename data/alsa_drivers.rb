require "yast"
require "yast2/execute"

# Auxiliary module to run a command and get its output
module Command
  # Returns the output of the given command
  #
  # @param args [Array<String>, Array<Array<String>>] the command to execute and
  #   its arguments. For a detailed description, see
  #   https://www.rubydoc.info/github/openSUSE/cheetah/Cheetah#run-class_method
  # @return [String] commmand output or an empty string if the command fails.
  def self.output(*args)
    Yast::Execute.locally!(*args, stdout: :capture)
  rescue Cheetah::ExecutionFailed => error
    puts error.message
    ""
  end
end

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
    @mod_path.match /\/([^\/]*).ko(?:.(?:xz|gz|zst))?$/
    return $1
  end

  # read the description from the driver
  def description
    Command::output("/sbin/modinfo", "-F", "description", @mod_path).strip
  end

  # read the device module aliases
  def modaliases
    aliases = Command::output("/sbin/modinfo", "-F", "alias", @mod_path).split("\n")
    aliases = aliases.grep(/^pci:/)

    mod_aliases = aliases.map { |a| ModAlias.new(a) }

    extra_ids = YAML.load_file("data_extra_id.yml")
    extra_ids = extra_ids.select { |id| id[0] == name }

    mod_aliases + extra_ids.map { |id| ModAlias.new("pci:v#{id[1]}d#{id[2]}sv*sd*") }
  end

  #  read the module parameters
  def params
    lst = Command::output("/sbin/modinfo", @mod_path).split("\n")
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
    files = (Dir.glob(File.join(path, "**", "snd-*.ko"))
             + Dir.glob(File.join(path, "**", "snd-*.ko.gz"))
             + Dir.glob(File.join(path, "**", "snd-*.ko.xz"))
             + Dir.glob(File.join(path, "**", "snd-*.ko.zst"))
            ).select { |f| File.file?(f) }

    files.sort! { |f1, f2| File.basename(f1) <=> File.basename(f2) }

    files.map { |f| AlsaModule.new(f) }
  end
end
