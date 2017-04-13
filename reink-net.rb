require 'snmp'
include SNMP

require "optparse"
require 'ostruct'

class Application
  def initialize
    @eeprom_link = '1.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.'
    @verbose=false
    @manager = SNMP::Manager.new(:host => '192.168.31.2', :version => :SNMPv1)
    options = parse_options
  end

  def send_data id
    @manager.get(id).each_varbind.first.value
  end

  def read_eeprom addr
    while addr.length < 4
      addr.insert(0, '0')
    end
    response = send_data @eeprom_link + '124.124.7.0.119.8.65.190.160.' + addr[2..3].hex.to_s + '.' + addr[0..1].hex.to_s
    response = response.match(/EE:[0-9A-F]{6}/).to_s
    chk_addr=response[3..6]
    abort('ERROR: Address and response address not equal: 0x' + addr + ' != 0x' + chk_addr) unless addr.eql?(addr)
    value=response[7..8]
    puts 'Address: 0x' + chk_addr + ' Value: 0x' + value if @verbose
    return value
  end

  def write_eeprom addr, value
    while addr.length < 4
      addr.insert(0, '0')
    end
    puts 'Write value: 0x' + value
    puts 'Before:'
    value_before = read_eeprom addr
    response = send_data @eeprom_link + '124.124.16.0.119.8.66.189.33.' + addr[2..3].hex.to_s + '.' + addr[0..1].hex.to_s + '.' + value.hex.to_s + '.68.98.117.117.109.102.122.98'
    puts response
    puts 'After:'
    value_after = read_eeprom addr
    puts 'Value: 0x' + value + ' Before: 0x' + value_before + ' After: 0x' + value_after
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
    serial_number_ascii=[serial_number_hex].pack("H*")
    puts serial_number_ascii + " Serial number"

    firmware_version = send_data(@eeprom_link + '118.105.1.0.0').match(/.+:(.+);/)[1]
    puts firmware_version + "\tFirmware version."

    waste_ink1 = (read_eeprom('0F') + read_eeprom('0E')).hex.to_s
    puts (waste_ink1.to_i/81.92).round.to_s + "%\tWaste ink counter 1. Value: " + waste_ink1

    waste_ink2 = (read_eeprom('11') + read_eeprom('10')).hex.to_s
    puts (waste_ink2.to_i/122.88).round.to_s + "%\tWaste ink counter 2. Value: " + waste_ink2

    hand_clean=read_eeprom('7E').hex.to_s
    puts hand_clean + "\tManual cleaning counter."

    timer_clean=read_eeprom('61').hex.to_s
    puts timer_clean + "\tTimer cleaning counter."

    head_pass=(read_eeprom('2F') + read_eeprom('2E') + read_eeprom('2D') + read_eeprom('2C')).hex.to_s
    puts head_pass + "\tTotal print pass counter."

    printed_pages=(read_eeprom('9F') + read_eeprom('9E')).hex.to_s
    puts printed_pages + "\tTotal print page counter."

    printed_pages_duplex=(read_eeprom('A1') + read_eeprom('A0')).hex.to_s
    puts printed_pages_duplex + "\tTotal print page counter (duplex)."

    printed_dvd=(read_eeprom('4B') + read_eeprom('4A')).hex.to_s
    puts printed_dvd + "\tTotal print CD-R counter."

    openclose_dvd=(read_eeprom('A3') + read_eeprom('A2')).hex.to_s
    puts openclose_dvd + "\tTotal print CD-R tray open/close counter."

    scaned_pages=(read_eeprom('01DD') + read_eeprom('01DC') + read_eeprom('01DB') + read_eeprom('01DA')).hex.to_s
    puts scaned_pages + "\tTotal scan counter."

    printer_fail1=read_eeprom('3B').to_s
    puts printer_fail1 + "\tLast printer fatal error code 1."

    printer_fail2=read_eeprom('C0').to_s
    puts printer_fail2 + "\tLast printer fatal error code 2."

    printer_fail3=read_eeprom('C1').to_s
    puts printer_fail3 + "\tLast printer fatal error code 3."

    printer_fail4=read_eeprom('C2').to_s
    puts printer_fail4 + "\tLast printer fatal error code 4."

    printer_fail5=read_eeprom('C3').to_s
    puts printer_fail5 + "\tLast printer fatal error code 5."

    scanner_fail1=read_eeprom('5C').to_s
    puts scanner_fail1 + "\tLast scanner fatal error code 1."

    cartridge_black1=read_eeprom('66').hex.to_s
    puts cartridge_black1 + "\tInk replacement counter for black (S)"
    cartridge_black2=read_eeprom('67').hex.to_s
    puts cartridge_black2 + "\tInk replacement counter for black (2S)"
    cartridge_black3=read_eeprom('62').hex.to_s
    puts cartridge_black3 + "\tInk replacement counter for black (3S)"

    cartridge_yellow1=read_eeprom('70').hex.to_s
    puts cartridge_yellow1 + "\tInk replacement counter for yellow (S)"
    cartridge_yellow2=read_eeprom('71').hex.to_s
    puts cartridge_yellow2 + "\tInk replacement counter for yellow (2S)"
    cartridge_yellow3=read_eeprom('AB').hex.to_s
    puts cartridge_yellow3 + "\tInk replacement counter for yellow (3S)"

    cartridge_magenta1=read_eeprom('68').hex.to_s
    puts cartridge_magenta1 + "\tInk replacement counter for magenta (S)"
    cartridge_magenta2=read_eeprom('69').hex.to_s
    puts cartridge_magenta2 + "\tInk replacement counter for magenta (2S)"
    cartridge_magenta3=read_eeprom('63').hex.to_s
    puts cartridge_magenta3 + "\tInk replacement counter for magenta (3S)"

    cartridge_cyan1=read_eeprom('6C').hex.to_s
    puts cartridge_cyan1 + "\tInk replacement counter for cyan (S)"
    cartridge_cyan2=read_eeprom('6D').hex.to_s
    puts cartridge_cyan2 + "\tInk replacement counter for cyan (2S)"
    cartridge_cyan3=read_eeprom('65').hex.to_s
    puts cartridge_cyan3 + "\tInk replacement counter for cyan (3S)"

    cartridge_light_magenta1=read_eeprom('6A').hex.to_s
    puts cartridge_light_magenta1 + "\tInk replacement counter for light magenta (S)"
    cartridge_light_magenta2=read_eeprom('6B').hex.to_s
    puts cartridge_light_magenta2 + "\tInk replacement counter for light magenta (2S)"
    cartridge_light_magenta3=read_eeprom('64').hex.to_s
    puts cartridge_light_magenta3 + "\tInk replacement counter for light magenta (3S)"

    cartridge_light_cyan1=read_eeprom('6E').hex.to_s
    puts cartridge_light_cyan1 + "\tInk replacement counter for light cyan (S)"
    cartridge_light_cyan2=read_eeprom('6F').hex.to_s
    puts cartridge_light_cyan2 + "\tInk replacement counter for light cyan (2S)"
    cartridge_light_cyan3=read_eeprom('9B').hex.to_s
    puts cartridge_light_cyan3 + "\tInk replacement counter for light cyan (3S)"
  end

  def dump_eeprom addr_start, addr_end
    a = addr_start.hex
    b = addr_end.hex
    a > b && abort('ERROR: Start address greater than end address: 0x' + addr_start + ' > 0x' + addr_end)
    while a <= b do
      value = read_eeprom a.to_s(16)
      @file.putc value.hex if !!defined? @file
      a += 1
    end
  end

  def hex_check addr
    raise OptionParser::InvalidArgument if addr !~ /^[0-9A-F]+$/i || addr.length != 2 && addr.length != 4
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
