require "./file"

# This module provides methods for parsing [Human Readable Archive (.hrx)](https://github.com/google/hrx)
# format.
#
# HRX is a plain-text, human-friendly format for defining multiple virtual text
# files in a single physical file, for situations when creating many physical
# files is undesirable, such as defining test cases for a text format.
module HRX
  # Raised when the parser encountered a format error.
  class InvalidError < Exception
    def initialize(message, @line : Int32 = 0, @column : Int32 = 0)
      message = "#{message} at #{@line}:#{column}"
      super(message)
    end
  end

  # Parse a HRX archive from a string.
  #
  # ```
  # hrx = HRX.parse("<==> foo\nFOO\n<==> bar\nBAR")
  # hrx.transform_values(&.content) # => {"foo" => "FOO", "bar" => "BAR"}
  # ```
  def self.parse(input : String) : Hash(String, HRX::File)
    parse(IO::Memory.new(input))
  end

  # Parse a HRX archive from an IO.
  #
  # ```
  # hrx = HRX.parse(IO::Memory.new("<==> foo\nFOO\n<==> bar\nBAR"))
  # hrx.transform_values(&.content) # => {"foo" => "FOO", "bar" => "BAR"}
  # ```
  def self.parse(io : IO) : Hash(String, HRX::File)
    files = {} of String => HRX::File
    parse(io) do |file|
      if file.path.ends_with?('/')
        file_path = file.path.rchop('/')
        dir_path = file.path
      else
        file_path = file.path
        dir_path = "#{file.path}/"
      end
      if files.has_key?(file_path) || files.has_key?(dir_path)
        raise InvalidError.new("#{file.path.inspect} defined twice", file.line, file.column)
      end
      files[file.path] = file
    end
    files
  end

  private def self.gets(io : IO, boundary)
    line = io.gets(chomp: false)
    return {true, false, nil} unless line

    line_size = line.bytesize

    starts_with_boundary = line.starts_with?(boundary)
    if starts_with_boundary
      line_size -= boundary.bytesize
    end

    ends_with_lf = line.ends_with?('\n')
    if ends_with_lf
      line_size -= 1 if starts_with_boundary
    end

    {starts_with_boundary, ends_with_lf, line.byte_slice(starts_with_boundary ? boundary.bytesize : 0, line_size)}
  end

  # Parse a HRX archive from an IO and yields `HRX::File` instances.
  #
  # ```
  # files = [] of HRX::File
  # HRX.parse(IO::Memory.new("<==> foo\nFOO\n<==> bar\nBAR")) do |file|
  #   files << file
  # end
  # files[0] # => HRX::File.new("foo", "FOO", nil, 1, 6)
  # files[1] # => HRX::File.new("bar", "BAR", nil, 3, 6)
  # ```
  def self.parse(io : IO, & : HRX::File ->)
    first_boundary = io.gets('>')
    return unless first_boundary
    line_number = 1

    raise InvalidError.new("Expected boundary", line_number, 1) unless first_boundary.size >= 3
    boundary = "<#{"=" * (first_boundary.size - 2)}>"
    raise InvalidError.new("Expected boundary", line_number, 1) unless boundary == first_boundary

    starts_with_boundary, ends_with_lf, line = gets(io, "")
    comment = nil

    while true
      raise InvalidError.new("invalid", line_number, 1) unless line

      if line.empty?
        # comment
        raise InvalidError.new("Expected space", line_number, boundary.size + 1) if comment
        path = nil
      else
        raise InvalidError.new("Expected space", line_number, boundary.size + 1) unless line[0] == ' '
        path = line.lstrip(' ')
        if path.empty?
          raise InvalidError.new("Expected a path", line_number, boundary.size + 2)
        end
      end

      unless ends_with_lf
        if (path && !path.ends_with?('/')) || !io.read_byte.nil?
          raise InvalidError.new("Expected newline", line_number, line.size + boundary.size + 1)
        end
      end

      body = String::Builder.new
      start_line_number = line_number

      while true
        starts_with_boundary, ends_with_lf, line = gets(io, boundary)
        line_number += 1 if line

        if !starts_with_boundary && path.try(&.ends_with?('/'))
          raise InvalidError.new("Expected boundary, not content for dir", line_number, 1)
        end

        unless starts_with_boundary
          body << line
          next
        end

        body.back(1) unless body.empty? || line.nil?

        if path
          yield HRX::File.new(path, body.to_s, comment, start_line_number, boundary.size + 2)
          comment = nil
        else
          comment = body.to_s
        end

        if line.nil?
          return
        else
          body = String::Builder.new
          break
        end
      end
    end
  end
end
