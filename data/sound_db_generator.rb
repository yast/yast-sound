# class for generating the sound card database

class SoucardDBGenerator
  private

  # generate the sound card names database
  def self.generate_cards(amodules, addons)
    index = 0
    ret = {}

    amodules.each do |m|

      mod_name = m.name
      cards = []

      addons.each do |a|
        if a[0] == mod_name
          cards << a[1]
        end
      end

      ret[index] = cards unless cards.empty?
      index += 1
    end

    ret
  end

  # generate index -> driver name mapping
  def self.generate_module_indices(amodules)
    index = 0
    ret = {}

    amodules.each do |m|
      ret[index] = m.name
      index += 1
    end

    ret
  end

  # generate module -> vendorID -> deviceID mapping
  def self.generate_indices(amodules)
    index = 0
    ret = {}

    amodules.each do |m|
      maliases = m.modaliases

      maliases.each do |malias|
        # to_s.to_i handles :ffffffff case
        vendor_id = malias.vid.to_s.to_i(16)
        ret[vendor_id] = {} unless ret.has_key? vendor_id
        vendormap = ret[vendor_id]

        device_id = malias.did.to_s.to_i(16)
        vendormap[device_id] = index
      end

      index += 1
    end

    ret
  end

  # generate vendor -> card names mapping
  def self.generate_vendors(amodules, addons)
    ret = {}

    all_names = amodules.map {|a| a.name}

    addons.each do |a|
      # is the driver present in the system?
      if all_names.include? a[0]
        card = a[1]

        if card.match /(.*),(.*)/
          model = $1.strip
          vendor = $2.strip

          ret[vendor] = [] unless ret.has_key? vendor

          ret[vendor] << model
        end
      end
    end

    ret
  end

  # generate driver -> driver info (description, parameters) mapping
  def self.generate_modules(amodules, joymodules, mixer)
    ret = {}

    amodules.each do |a|
      name = a.name
      mod = {}

      mod['description'] = a.description

      # add joystick data if available
      if joymodules.has_key? name
        mod['joystick'] = { 'GAMEPORT_MODULE' => joymodules[name] }
      end

      # add mixer data if available
      if mixer.has_key? name
        mod['mixer'] = mixer[name]
      end

      parameters = {}

      a.params.each do |p|
        param_info = {'descr' => p.description}
        if p.type == :bool
          param_info["allows"] = "{{0,Disabled},{1,Enabled}}"
          param_info["default"] = "0"
          param_info["dialog"] = "check"
        end

        parameters[p.name] = param_info
      end

      mod["params"] = parameters unless parameters.empty?

      ret[name] = mod
    end

    ret
  end

  public

  # generate the complete sound card database
  # read the static databases,
  # create the subparts and put them all together
  def self.generate_sound_card_db(path)
    amodules = AlsaModule.find_all path

    # add these drivers although they don't contain any PCI aliases
    # (dummy drivers, USB drivers, PPC drivers)
    xtra_drivers = ['snd-dummy', 'snd-virmidi', 'snd-aoa', 'snd-usb-audio',
      'snd-usb-caiaq', 'snd-ua101', 'snd-usb-us122l', 'snd-usb-usx2y']

    amodules.reject!{|m| m.modaliases.size.zero? && !xtra_drivers.include?(m.name)}

    card_addons = eval(File.read(File.join(File.dirname(__FILE__), 'data_cards.rb')))
    joy_modules = eval(File.read(File.join(File.dirname(__FILE__), 'data_joystick.rb')))
    mixer = eval(File.read(File.join(File.dirname(__FILE__), 'data_mixer.rb')))

    path.match /^\/lib\/modules\/([^\/]*)\//
    kernel_ver = $1

    sound_card_db = {
      "cards" => generate_cards(amodules, card_addons),
      "indices" => generate_indices(amodules),
      "mod_idx" => generate_module_indices(amodules),
      "modules" => generate_modules(amodules, joy_modules, mixer),
      "vendors" => generate_vendors(amodules, card_addons),
      "kernel" => kernel_ver
    }

    # add a header with kernel version string and YCP wrapping
    header = "/* This file was automatically generated for kernel version #{$1} */\n"
    header +=<<EOF

{
textdomain "sound_db";

return
EOF

    footer =<<EOF
;
}
EOF

    # convert the Ruby structure to YCP format string
    # add the header and the footer
    header + sound_card_db.to_ycp + footer
  end

end

