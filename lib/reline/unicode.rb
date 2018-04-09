require 'reline'

class Reline::Unicode
  def self.get_mbchar_byte_size_by_first_char(c)
    # Checks UTF-8 character byte size
    case c.ord
    # 0b0xxxxxxx
    when ->(code) { (code ^ 0b10000000).allbits?(0b10000000) } then 1
    # 0b110xxxxx
    when ->(code) { (code ^ 0b00100000).allbits?(0b11100000) } then 2
    # 0b1110xxxx
    when ->(code) { (code ^ 0b00010000).allbits?(0b11110000) } then 3
    # 0b11110xxx
    when ->(code) { (code ^ 0b00001000).allbits?(0b11111000) } then 4
    # 0b111110xx
    when ->(code) { (code ^ 0b00000100).allbits?(0b11111100) } then 5
    # 0b1111110x
    when ->(code) { (code ^ 0b00000010).allbits?(0b11111110) } then 6
    # successor of mbchar
    else 0
    end
  end

  def self.get_mbchar_width(mbchar)
    case mbchar
    when /\p{M}/
      0
    when EastAsianWidth::TYPE_F, EastAsianWidth::TYPE_W, EastAsianWidth::TYPE_A
      2
    when EastAsianWidth::TYPE_H, EastAsianWidth::TYPE_NA, EastAsianWidth::TYPE_N
      1
    else
      nil
    end
  end

  def self.get_next_mbchar_size(line, byte_pointer)
    base_char = nil
    total_byte_size = 0
    while byte_pointer < line.bytesize
      byte_size = get_mbchar_byte_size_by_first_char(line.bytes[byte_pointer])
      mbchar = line.byteslice(byte_pointer, byte_size)
      break if base_char and /\P{M}/.match?(mbchar)
      base_char = mbchar unless base_char
      byte_pointer += byte_size
      total_byte_size += byte_size
    end
    total_byte_size
  end

  def self.get_prev_mbchar_size(line, byte_pointer)
    base_char = nil
    total_byte_size = 0
    while byte_pointer > 0
      byte_pointer -= 1
      next if (byte_size = get_mbchar_byte_size_by_first_char(line.bytes[byte_pointer])).zero?
      total_byte_size += byte_size
      mbchar = line.byteslice(byte_pointer, byte_size)
      if /\P{M}/.match?(mbchar)
        base_char = mbchar
        break
      end
    end
    total_byte_size
  end

  def self.em_forward_word(line, byte_pointer)
    width = 0
    byte_size = 0
    while line.bytesize > (byte_pointer + byte_size)
      size = get_next_mbchar_size(line, byte_pointer + byte_size)
      mbchar = line.byteslice(byte_pointer + byte_size, size)
      break if mbchar =~ /\w/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    while line.bytesize > (byte_pointer + byte_size)
      size = get_next_mbchar_size(line, byte_pointer + byte_size)
      mbchar = line.byteslice(byte_pointer + byte_size, size)
      break if mbchar =~ /\W/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    [byte_size, width]
  end

  def self.em_backward_word(line, byte_pointer)
    width = 0
    byte_size = 0
    while 0 < (byte_pointer - byte_size)
      size = get_prev_mbchar_size(line, byte_pointer - byte_size)
      mbchar = line.byteslice(byte_pointer - byte_size - size, size)
      break if mbchar =~ /\w/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    while 0 < (byte_pointer - byte_size)
      size = get_prev_mbchar_size(line, byte_pointer - byte_size)
      mbchar = line.byteslice(byte_pointer - byte_size - size, size)
      break if mbchar =~ /\W/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    [byte_size, width]
  end

  def self.vi_forward_word(line, byte_pointer)
    width = 0
    byte_size = 0
    while (line.bytesize - 1) > (byte_pointer + byte_size)
      size = get_next_mbchar_size(line, byte_pointer + byte_size)
      mbchar = line.byteslice(byte_pointer + byte_size, size)
      break if mbchar =~ /\s/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    while (line.bytesize - 1) > (byte_pointer + byte_size)
      size = get_next_mbchar_size(line, byte_pointer + byte_size)
      mbchar = line.byteslice(byte_pointer + byte_size, size)
      break if mbchar =~ /\S/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    [byte_size, width]
  end

  def self.vi_forward_end_word(line, byte_pointer)
    if (line.bytesize - 1) > byte_pointer
      size = get_next_mbchar_size(line, byte_pointer)
      mbchar = line.byteslice(byte_pointer, size)
      width = get_mbchar_width(mbchar)
      byte_size = size
    else
      return [0, 0]
    end
    while (line.bytesize - 1) > (byte_pointer + byte_size)
      size = get_next_mbchar_size(line, byte_pointer + byte_size)
      mbchar = line.byteslice(byte_pointer + byte_size, size)
      break if mbchar =~ /\S/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    prev_width = width
    prev_byte_size = byte_size
    while (line.bytesize - 1) > (byte_pointer + byte_size)
      size = get_next_mbchar_size(line, byte_pointer + byte_size)
      mbchar = line.byteslice(byte_pointer + byte_size, size)
      break if mbchar =~ /\s/
      prev_width = width
      prev_byte_size = byte_size
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    [prev_byte_size, prev_width]
  end

  def self.vi_backward_word(line, byte_pointer)
    width = 0
    byte_size = 0
    while 0 < (byte_pointer - byte_size)
      size = get_prev_mbchar_size(line, byte_pointer - byte_size)
      mbchar = line.byteslice(byte_pointer - byte_size - size, size)
      break if mbchar =~ /\S/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    while 0 < (byte_pointer - byte_size)
      size = get_prev_mbchar_size(line, byte_pointer - byte_size)
      mbchar = line.byteslice(byte_pointer - byte_size - size, size)
      break if mbchar =~ /\s/
      width += get_mbchar_width(mbchar)
      byte_size += size
    end
    [byte_size, width]
  end
end

require 'reline/unicode/east_asian_width'
