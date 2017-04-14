require 'snmp'
include SNMP

require "optparse"
require 'ostruct'

class Application
  def initialize
    @eeprom_link = '1.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.'
    @verbose = false
    @password = [ 0x77, 0x08 ]
    @waste_ink1 = [ 0x0E, 0x0F]
    @waste_ink2 = [ 0x10, 0x11]
    @manager = SNMP::Manager.new(:host => '192.168.31.2', :version => :SNMPv1)
    options = parse_options
  end

  def send_data id
    @manager.get(id).each_varbind.first.value
  end

  def read_eeprom addr
    puts addr
    while addr.length < 4
      addr.insert(0, '0')
    end
    response = send_data "%s124.124.7.0.%i.%i.65.190.160.%i.%i" % [@eeprom_link, @password[0], @password[1], addr[2..3].hex, addr[0..1].hex]
    raise 'EEPROM reading failed' if response.match(/NA/)
    response = response.match(/EE:[0-9A-F]{6}/).to_s
    chk_addr=response[3..6]
    addr.eql?(addr) || abort("ERROR: Address and response address not equal: 0x%02X != 0x%02X" % [addr.hex, chk_addr.hex])
    value=response[7..8]
    @verbose && puts("Address: 0x%04X Value: 0x%02X" % [chk_addr.hex, value.hex])
    return value
  end

  def write_eeprom addr, value
    while addr.length < 4
      addr.insert(0, '0')
    end
    value_before = read_eeprom addr
    response = send_data "%s124.124.16.0.%i.%i.66.189.33.%i.%i.%i.68.98.117.117.109.102.122.98" % [@eeprom_link, @password[0], @password[1], addr[2..3].hex, addr[0..1].hex, value.hex]
    value_after = read_eeprom addr
    puts "Address: 0x%04X Value: 0x%02X Before: 0x%02X After: 0x%02X (%s)" % [addr.hex, value.hex, value_before.hex, value_after.hex, response.strip]
    value != value_after && abort('ERROR: Write error!')
  end

  def info
    #Model fullname
    puts send_data '1.3.6.1.2.1.25.3.2.1.3.1'

    #Model code
    puts send_data '1.3.6.1.2.1.1.5.0'

    #EEPS2 version
    puts send_data '1.3.6.1.2.1.2.2.1.2.1'

    serial_number_hex = (0xE7..0xF0).collect{|i| read_eeprom i.to_s(16)}.join
    puts "%s Serial number" % [serial_number_hex].pack("H*")

    puts "%s\tFirmware version." % send_data(@eeprom_link + '118.105.1.0.0').match(/.+:(.+);/)[1]

    waste_ink_levels

    puts "%i\tManual cleaning counter." % read_eeprom('7E').hex
    puts  "%i\tTimer cleaning counter." % read_eeprom('61').hex

    puts "%i\tTotal print pass counter." % (read_eeprom('2F') + read_eeprom('2E') + read_eeprom('2D') + read_eeprom('2C')).hex

    puts "%i\tTotal print page counter." % (read_eeprom('9F') + read_eeprom('9E')).hex
    puts "%i\tTotal print page counter (duplex)." % (read_eeprom('A1') + read_eeprom('A0')).hex

    puts "%i\tTotal print CD-R counter." % (read_eeprom('4B') + read_eeprom('4A')).hex
    puts "%i\tTotal print CD-R tray open/close counter." % (read_eeprom('A3') + read_eeprom('A2')).hex

    puts "%i\tTotal scan counter." % (read_eeprom('01DD') + read_eeprom('01DC') + read_eeprom('01DB') + read_eeprom('01DA')).hex

    puts "0x%s\tLast printer fatal error code 1." % read_eeprom('3B')
    puts "0x%s\tLast printer fatal error code 2." % read_eeprom('C0')
    puts "0x%s\tLast printer fatal error code 3." % read_eeprom('C1')
    puts "0x%s\tLast printer fatal error code 4." % read_eeprom('C2')
    puts "0x%s\tLast printer fatal error code 5." % read_eeprom('C3')
    puts "0x%s\tLast scanner fatal error code 1." % read_eeprom('5C')

    puts "%i\tInk replacement counter for black (1S)" % read_eeprom('66').hex
    puts "%i\tInk replacement counter for black (2S)" % read_eeprom('67').hex
    puts "%i\tInk replacement counter for black (3S)" % read_eeprom('62').hex

    puts "%i\tInk replacement counter for yellow (1S)" % read_eeprom('70').hex
    puts "%i\tInk replacement counter for yellow (2S)" % read_eeprom('71').hex
    puts "%i\tInk replacement counter for yellow (3S)" % read_eeprom('AB').hex

    puts "%i\tInk replacement counter for magenta (1S)" % read_eeprom('68').hex
    puts "%i\tInk replacement counter for magenta (2S)" % read_eeprom('69').hex
    puts "%i\tInk replacement counter for magenta (3S)" % read_eeprom('63').hex

    puts "%i\tInk replacement counter for cyan (1S)" % read_eeprom('6C').hex
    puts "%i\tInk replacement counter for cyan (2S)" % read_eeprom('6D').hex
    puts "%i\tInk replacement counter for cyan (3S)" % read_eeprom('65').hex

    puts "%i\tInk replacement counter for light magenta (1S)" % read_eeprom('6A').hex
    puts "%i\tInk replacement counter for light magenta (2S)" % read_eeprom('6B').hex
    puts "%i\tInk replacement counter for light magenta (3S)" % read_eeprom('64').hex

    puts "%i\tInk replacement counter for light cyan (1S)" % read_eeprom('6E').hex
    puts "%i\tInk replacement counter for light cyan (2S)" % read_eeprom('6F').hex
    puts "%i\tInk replacement counter for light cyan (3S)" % read_eeprom('9B').hex
  end

  def dump_eeprom addr_start, addr_end
    a = addr_start.hex
    b = addr_end.hex
    a > b && abort("ERROR: Start address greater than end address: 0x%04X > 0x%04X" % [addr_start, addr_end])
    while a <= b do
      value = read_eeprom a.to_s(16)
      @file.putc value.hex if !!defined? @file
      a += 1
    end
  end

  def hex_check addr
    raise OptionParser::InvalidArgument if addr !~ /^[0-9A-F]+$/i || addr.length != 2 && addr.length != 4
  end

  def waste_ink_levels
    waste_ink_val1 = (read_eeprom(@waste_ink1[1].to_s(16)) + read_eeprom(@waste_ink1[0].to_s(16))).hex
    puts "%i%%\tWaste ink counter 1. Value: %i" % [(waste_ink_val1/81.92).round, waste_ink_val1]

    waste_ink_val2 = (read_eeprom(@waste_ink2[1].to_s(16)) + read_eeprom(@waste_ink2[0].to_s(16))).hex
    puts "%i%%\tWaste ink counter 2. Value: %i" % [(waste_ink_val2/122.88).round, waste_ink_val2]
  end

  def reset_waste_ink
    waste_ink_levels
    write_eeprom @waste_ink1[0].to_s(16),'00'
    write_eeprom @waste_ink1[1].to_s(16),'00'
    write_eeprom @waste_ink2[0].to_s(16),'00'
    write_eeprom @waste_ink2[1].to_s(16),'00'
    waste_ink_levels
  end

  def brute_force
    puts 'Brute Force started. Please wait'
    (0x0000..0xffff).each do |i|
      @password = [i].pack('n').unpack('C*')
      puts 'Trying 0x%02X 0x%02X' % @password
      break if read_eeprom('00') rescue next
    end
    puts "Password was found: 0x%02X 0x%02X" % @password
  end

  def get_ink_level
    result = send_data @eeprom_link + '115.116.1.0.1'
    puts "%i%%\tCyan" % result[0x19].ord
    puts "%i%%\tYellow" % result[0x1C].ord
    puts "%i%%\tLight Cyan" % result[0x1F].ord
    puts "%i%%\tBlack" % result[0x22].ord
    puts "%i%%\tMagenta" % result[0x25].ord
    puts "%i%%\tLight Magenta" % result[0x28].ord
  end

  def parse_options
    options = OpenStruct.new
    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: reink-net [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on( '-s', '--save [FILE]', String, 'Save dump to file' ) do |args|
        @file = File.new(args, 'wb')
      end
      opts.on( '-r', '--read [HEX](-[HEX])', String, 'Read value in address 0000-FFFF' ) do |args|
        raise OptionParser::InvalidArgument unless args[0] != '-' && args[-1] != '-'
        addr_start=args.split('-').first.upcase
        args.include?('-') ? addr_end=args.split('-').last.upcase : addr_end=addr_start
        hex_check addr_start
        hex_check addr_end
        @verbose=true
        dump_eeprom addr_start, addr_end
      end
      opts.on( '-w', '--write [HEX]=[HEX]', String, 'Write value to address 0000-FFFF' ) do |args|
        raise OptionParser::InvalidArgument unless args.include?('=') && args[0] != '=' && args[-1] != '='
        address=args.split('=').first.upcase
        value=args.split('=').last.upcase
        hex_check address
        hex_check value
        write_eeprom address, value
      end
      opts.on( '-i', '--info', 'Read printer info' ) do
        info
      end
      opts.on( '-y', '--waste', 'Reset waste ink counter' ) do
        reset_waste_ink
      end
      opts.on( '-l', '--level', 'Get ink level' ) do
        get_ink_level
      end
      opts.on( '-b', '--brute', 'Get printer password (Brute Force)' ) do
        brute_force
      end
    end
    optparse.parse!

    @file.close if !!defined? @file

#    raise OptionParser::InvalidArgument
    options
  rescue OptionParser::InvalidArgument
    puts optparse
    exit
  end
end

Application.new
#manager = SNMP::Manager.new(:host => '192.168.31.2', :port => 161)
#varbind = VarBind.new("iso.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.118.105.1.0.0", NIL)
#@manager = SNMP::Manager.new(:host => '192.168.31.2', :version => :SNMPv1)

# def get_data id
#  response = @manager.get(id)
#  response.each_varbind {|vb| puts vb.inspect}
#end
#get_data '1.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.118.105.1.0.0' #firmware_version
#get_data '1.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.124.124.7.0.119.8.65.190.160.' + 0xff.to_s + '.' + 0xff.to_s
#puts 0xe7.to_s
#@manager.close
