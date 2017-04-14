require 'snmp'
include SNMP

require "optparse"
require 'ostruct'

class Printer
  def initialize
    @printers = {
      EPSON660ABD: {
        name: 'Epson Artisan 730 / Stylus Photo PX730WD',
        password: [ 0x08, 0x77 ],
        waste_ink1: [ 0x0E, 0x0F ],
        waste_ink2: [ 0x10, 0x11 ],
        colors: [ 'cyan', 'yellow', 'light_cyan', 'black', 'magenta', 'light_magenta' ],
        color_code: {
          cyan: 0x14,
          yellow: 0x28,
          light_cyan: 0x18,
          black: 0x1C,
          magenta: 0x20,
          light_magenta: 0x24,
        },
      },
    }
  end

  def printer_select model_code
    @printers[model_code.to_sym]
  end
end

class Application
  def initialize
    @eeprom_link = '1.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.'
    @verbose = false
    @manager = SNMP::Manager.new(:host => ARGV[0], :version => :SNMPv1)
    @printer = Printer.new.printer_select(model_code)
    puts 'Printer support: %s' % @printer[:name]
    options = parse_options
  end

  def send_data id
    @manager.get(id).each_varbind.first.value
  end

  def read_eeprom addr
    split_addr=[addr].pack('n').unpack('C*')
    response = send_data "%s124.124.7.0.%i.%i.65.190.160.%i.%i" % [@eeprom_link, @printer[:password][1], @printer[:password][0], split_addr[1], split_addr[0]]
    raise 'EEPROM reading failed' if response.match(/NA/)
    response = response.match(/EE:[0-9A-F]{6}/).to_s
    chk_addr=response[3..6].hex
    addr.eql?(addr) || abort("ERROR: Address and response address not equal: 0x%02X != 0x%02X" % [addr, chk_addr])
    value=response[7..8].hex
    @verbose && puts("Address: 0x%04X Value: 0x%02X" % [chk_addr, value])
    return value
  end

  def read_eeprom_multibyte addr
    addr.reverse.collect{|i| read_eeprom(i).to_s(16)}.join.hex
  end

  def write_eeprom addr, value
    split_addr=[addr].pack('n').unpack('C*')
    value_before = read_eeprom addr
    response = send_data "%s124.124.16.0.%i.%i.66.189.33.%i.%i.%i.68.98.117.117.109.102.122.98" % [@eeprom_link, @printer[:password][1], @printer[:password][0], split_addr[1], split_addr[0], value]
    value_after = read_eeprom addr
    puts "Address: 0x%04X Value: 0x%02X Before: 0x%02X After: 0x%02X (%s)" % [addr, value, value_before, value_after, response.strip]
    value != value_after && abort('ERROR: Write error!')
  end

  def model_code
    send_data '1.3.6.1.2.1.1.5.0'
  end

  def info
    #Model fullname
    puts send_data '1.3.6.1.2.1.25.3.2.1.3.1'

    #Model code
    puts model_code

    #EEPS2 version
    puts send_data '1.3.6.1.2.1.2.2.1.2.1'

    puts "%s Serial number" % (0xE7..0xF0).collect{|i| read_eeprom i}.pack('C*')

    puts "%s\tFirmware version." % send_data(@eeprom_link + '118.105.1.0.0').match(/.+:(.+);/)[1]

    waste_ink_levels

    puts "%i\tManual cleaning counter." % read_eeprom(0x7E)
    puts  "%i\tTimer cleaning counter." % read_eeprom(0x61)

    puts "%i\tTotal print pass counter." % read_eeprom_multibyte([0x2C,0x2D,0x2E,0x2F])

    puts "%i\tTotal print page counter." % read_eeprom_multibyte([0x9E,0x9F])
    puts "%i\tTotal print page counter (duplex)." % read_eeprom_multibyte([0xA0,0xA1])

    puts "%i\tTotal print CD-R counter." % read_eeprom_multibyte([0x4A,0x4B])
    puts "%i\tTotal print CD-R tray open/close counter." % read_eeprom_multibyte([0xA2,0xA3])

    puts "%i\tTotal scan counter." % read_eeprom_multibyte([0x01DA,0x01DB,0x01DC,0x01DD])

    puts "0x%02X\tLast printer fatal error code 1." % read_eeprom(0x3B)
    puts "0x%02X\tLast printer fatal error code 2." % read_eeprom(0xC0)
    puts "0x%02X\tLast printer fatal error code 3." % read_eeprom(0xC1)
    puts "0x%02X\tLast printer fatal error code 4." % read_eeprom(0xC2)
    puts "0x%02X\tLast printer fatal error code 5." % read_eeprom(0xC3)
    puts "0x%02X\tLast scanner fatal error code 1." % read_eeprom(0x5C)

    puts "%i\tInk replacement counter for black (1S)" % read_eeprom(0x66)
    puts "%i\tInk replacement counter for black (2S)" % read_eeprom(0x67)
    puts "%i\tInk replacement counter for black (3S)" % read_eeprom(0x62)

    puts "%i\tInk replacement counter for yellow (1S)" % read_eeprom(0x70)
    puts "%i\tInk replacement counter for yellow (2S)" % read_eeprom(0x71)
    puts "%i\tInk replacement counter for yellow (3S)" % read_eeprom(0xAB)

    puts "%i\tInk replacement counter for magenta (1S)" % read_eeprom(0x68)
    puts "%i\tInk replacement counter for magenta (2S)" % read_eeprom(0x69)
    puts "%i\tInk replacement counter for magenta (3S)" % read_eeprom(0x63)

    puts "%i\tInk replacement counter for cyan (1S)" % read_eeprom(0x6C)
    puts "%i\tInk replacement counter for cyan (2S)" % read_eeprom(0x6D)
    puts "%i\tInk replacement counter for cyan (3S)" % read_eeprom(0x65)

    puts "%i\tInk replacement counter for light magenta (1S)" % read_eeprom(0x6A)
    puts "%i\tInk replacement counter for light magenta (2S)" % read_eeprom(0x6B)
    puts "%i\tInk replacement counter for light magenta (3S)" % read_eeprom(0x64)

    puts "%i\tInk replacement counter for light cyan (1S)" % read_eeprom(0x6E)
    puts "%i\tInk replacement counter for light cyan (2S)" % read_eeprom(0x6F)
    puts "%i\tInk replacement counter for light cyan (3S)" % read_eeprom(0x9B)
  end

  def dump_eeprom addr_start, addr_end
    a = addr_start
    b = addr_end
    a > b && abort("ERROR: Start address greater than end address: 0x%04X > 0x%04X" % [addr_start, addr_end])
    while a <= b do
      value = read_eeprom a
      @file.putc value if !!defined? @file
      a += 1
    end
  end

  def waste_ink_levels
    val1 = read_eeprom_multibyte(@printer[:waste_ink1])
    puts "%i%%\tWaste ink counter 1. Value: %i" % [(val1/81.92).round, val1]

    val2 = read_eeprom_multibyte(@printer[:waste_ink2])
    puts "%i%%\tWaste ink counter 2. Value: %i" % [(val2/122.88).round, val2]
  end

  def reset_waste_ink
    waste_ink_levels
    write_eeprom @printer[:waste_ink1][0],0
    write_eeprom @printer[:waste_ink1][1],0
    write_eeprom @printer[:waste_ink2][0],0
    write_eeprom @printer[:waste_ink2][1],0
    waste_ink_levels
  end

  def brute_force
    puts 'Brute Force started. Please wait'
    (0x0000..0xffff).each do |i|
      @printer[:password] = [i].pack('n').unpack('C*')
      puts 'Trying 0x%02X 0x%02X' % @printer[:password]
      break if read_eeprom(0x00) rescue next
    end
    puts "Password was found: 0x%02X 0x%02X" % @printer[:password]
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
      opts.banner = "Usage: reink-net [ip] [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on( '-s', '--save [FILE]', String, 'Save dump to file' ) do |args|
        @file = File.new(args, 'wb')
      end
      opts.on( '-r', '--read [HEX](-[HEX])', String, 'Read value in address 0000-FFFF' ) do |args|
        raise OptionParser::InvalidArgument unless args.match(/[^0-9a-fA-F-]+/).nil? or args[0] != '-' or args[-1] != '-'
        args = args.split('-')
        addr_start=args[0].hex # FF case
        args[1] ? addr_end=args[1].hex : addr_end=addr_start # 00-FF case
        raise OptionParser::InvalidArgument if addr_start > 0xFFFF or addr_end > 0xFFFF
        @verbose=true # Enable messages
        dump_eeprom addr_start, addr_end
      end
      opts.on( '-w', '--write [HEX]=[HEX]', String, 'Write value to address 0000-FFFF' ) do |args|
        raise OptionParser::InvalidArgument unless args.match(/[^0-9a-fA-F-]+/).nil? or args.include?('=') or args[0] != '=' or args[-1] != '='
        args = args.split('=')
        address=args[0].hex
        value=args[1].hex
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

    options
  rescue OptionParser::InvalidArgument
    puts optparse
    exit
  end
end

Application.new
