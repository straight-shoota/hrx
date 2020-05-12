# This type represents a file entry in an HRX archive.
struct HRX::File
  getter path : String
  getter content : String
  getter comment : String?
  getter line : Int32
  getter column : Int32

  def initialize(@path : String, @content : String, @comment : String? = nil, @line : Int32 = 0, @column : Int32 = 0)
  end
end
