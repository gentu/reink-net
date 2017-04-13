require 'snmp'
include SNMP

require "optparse"
require 'ostruct'

class Application
  def initialize
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
    response = send_data '1.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.124.124.7.0.119.8.65.190.160.' + addr[2..3].hex.to_s + '.' + addr[0..1].hex.to_s
    response = response.match(/EE:[0-9A-F]{6}/).to_s
    chk_addr=response[3..6]
    abort('ERROR: Address and response address not equal: 0x' + addr + ' != 0x' + chk_addr) unless addr.eql?(addr)
    value=response[7..8]
    puts 'Address: 0x' + chk_addr + ' Value: 0x' + value
    return value
  end

  def write_eeprom addr, value
    while addr.length < 4
      addr.insert(0, '0')
    end
    puts 'Write value: 0x' + value
    puts 'Before:'
    value_before = read_eeprom addr
    response = send_data '1.3.6.1.4.1.1248.1.2.2.44.1.1.2.1.124.124.16.0.119.8.66.189.33.' + addr[2..3].hex.to_s + '.' + addr[0..1].hex.to_s +'.' + value.hex.to_s + '.68.98.117.117.109.102.122.98'
    puts response
    puts 'After:'
    value_after = read_eeprom addr
    value != value_after && abort('ERROR: Write error!')
    #puts 'Value: 0x' + value + ' Before: 0x' + value_before + ' After: 0x' + value_after
  end

  def dump_eeprom addr_start, addr_end
    a = addr_start.hex
    b = addr_end.hex
    a > b && abort('ERROR: Start address greater than end address: 0x' + addr_start + ' > 0x' + addr_end)
    file = File.new('epson_dump.txt', 'wb')
    while a <= b do
      value = read_eeprom a.to_s(16)
      file.putc value.hex
      a += 1
    end
    file.close
  end

  def hex_check addr
    raise OptionParser::InvalidArgument if addr !~ /^[0-9A-F]+$/i || addr.length != 2 && addr.length != 4
  end

  def parse_options
    options = OpenStruct.new
    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: rubink [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on( '-r', '--read [HEX]', String, 'Read value in address 0000-FFFF' ) do |address|
        hex_check address
        read_eeprom address
      end
      opts.on( '-w', '--write [HEX]=[HEX]', String, 'Write value to address 0000-FFFF' ) do |args|
        raise OptionParser::InvalidArgument unless args.include?('=') && args[0] != '=' && args[-1] != '='
        address=args.split('=').first
        value=args.split('=').last
        hex_check address
        hex_check value
        write_eeprom address, value
      end
      opts.on( '-d', '--dump [HEX]-[HEX]', String, 'Dump memory from/to address 0000-FFFF' ) do |args|
        raise OptionParser::InvalidArgument unless args.include?('-') && args[0] != '-' && args[-1] != '-'
        addr_start=args.split('-').first
        addr_end=args.split('-').last
        hex_check addr_start
        hex_check addr_end
        dump_eeprom addr_start, addr_end
      end
    end
    optparse.parse!

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
