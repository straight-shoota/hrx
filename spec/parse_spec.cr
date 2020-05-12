require "../src/hrx"
require "spec"

private def parse_contents(string)
  HRX.parse(string).transform_values(&.content)
end

private def it_fails_parsing(description, hrx, error_message, *, file = __FILE__, line = __LINE__)
  it description, file: file, line: line do
    expect_raises(HRX::InvalidError, error_message) do
      HRX.parse(hrx)
    end
  end
end

describe HRX do
  describe ".parse" do
    it "empty archive" do
      HRX.parse("").should be_empty
    end

    it "comment only" do
      HRX.parse("<==>\n").should be_empty
    end

    it "one file" do
      parse_contents("<==> foo\nFOO").should eq({"foo" => "FOO"})
    end

    it "one file and comment" do
      parse_contents("<==>\n<==> foo\nFOO").should eq({"foo" => "FOO"})
    end

    it "empty files" do
      parse_contents("<==> foo\n<==> bar\n").should eq({"foo" => "", "bar" => ""})
    end

    it "files" do
      parse_contents("<==> foo\nFOO\n<==> bar\nBAR").should eq({"foo" => "FOO", "bar" => "BAR"})
    end

    it "multiline files" do
      parse_contents("<==> foo\nFOO\nFOO\n<==> bar\nBAR\nBAR").should eq({"foo" => "FOO\nFOO", "bar" => "BAR\nBAR"})
      parse_contents("<==> foo\nFOO\nFOO\n\n<==> bar\nBAR\nBAR\n").should eq({"foo" => "FOO\nFOO\n", "bar" => "BAR\nBAR\n"})
    end

    it "boundary-like sequences" do
      parse_contents(<<-HRX).should eq({"file" => <<-CONTENT})
      <===> file
      <==>
      inline <===>
      <====>
      HRX
      <==>
      inline <===>
      <====>
      CONTENT
    end

    it "comment" do
      files = [] of HRX::File
      HRX.parse(IO::Memory.new(<<-HRX)) do |file|
        <===>
        FOO
        <===> file
        BAR
        HRX
        files << file
      end
      files.first.should eq HRX::File.new("file", "BAR", "FOO", 3, 7)
    end

    it "boundary-like sequence in comment" do
      files = [] of HRX::File
      HRX.parse(IO::Memory.new(<<-HRX)) do |file|
        <===>
        <==>
        inline <===>
        <====>
        <===> file

        HRX
        files << file
      end
      files.first.comment.should eq <<-COMMENT
        <==>
        inline <===>
        <====>
        COMMENT
    end

    it "directory" do
      parse_contents("<===> foo/").should eq({"foo/" => ""})
    end

    describe "invalid format" do
      it_fails_parsing "doesn't start with a boundary", "file\n", "Expected boundary at 1:1"
      it_fails_parsing "starts with an unclosed boundary", "<== file\n", "Expected boundary at 1:1"
      it_fails_parsing "starts with an unopened boundary", "==> file\n", "Expected boundary at 1:1"
      it_fails_parsing "starts with a malformed boundary", "<> file\n", "Expected boundary at 1:1"

      it_fails_parsing "has a directory with contents", "<===> dir/\ncontents", "Expected boundary, not content for dir at 2:1"

      it_fails_parsing "has duplicate files", "<=> file\n<=> file\n", %("file" defined twice at 2:5)
      it_fails_parsing "has duplicate directories", "<=> dir/\n<=> dir/\n", %("dir/" defined twice at 2:5)
      it_fails_parsing "has file with the same name as a directory", "<=> foo/\n<=> foo\n", %("foo" defined twice at 2:5)

      it_fails_parsing "boundary isn't followed by a space", "<=>file\n", "Expected space at 1:4"
      it_fails_parsing "boundary isn't followed by a path", "<=> \n", "Expected a path at 1:5"
      it_fails_parsing "has a file without a newline", "<=> file", "Expected newline at 1:9"

      it_fails_parsing "middle boundary isn't followed by a space", "<=> file 1\n<=>file 2\n", "Expected space at 2:4"
      it_fails_parsing "middle boundary isn't followed by a path", "<=> file 1\n<=> \n", "Expected a path at 2:5"
      it_fails_parsing "middle boundary has a file without a newline", "<=> file 1\n<=> file", "Expected newline at 2:9"

      describe "sequential comments" do
        it_fails_parsing "standalone", "<=>\ncomment1\n<=>\ncomment2\n", "Expected space at 3:4"
        it_fails_parsing "before file", "<=>\ncomment1\n<=>\ncomment2\n<=>\n file", "Expected space at 3:4"
        it_fails_parsing "at end", "<=> file\n<=>\ncomment1\n<=>\ncomment2\n<=>\n file", "Expected space at 4:4"
      end

      pending "implicit directories" do
        it_fails_parsing "has file with the same name as an earlier implicit directory", "<=> foo/bar\n<=> foo\n", %("foo" defined twice)
        it_fails_parsing "has file with the same name as a later implicit directory", "<=> foo\n<=> foo/bar\n", %("foo" defined twice)
      end
    end
  end
end
