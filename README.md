# hrx

This shard provides a parser for the [Human Readable Archive (HRX)](https://github.com/google/hrx) format.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     hrx:
       github: straight-shoota/hrx
   ```

2. Run `shards install`

## Usage

```crystal
require "hrx"

File.write("archive.hrx", "<==> foo.txt\nFOO\n<==> bar.txt\nBAR")
archive = File.open("archive.hrx", "r") do |io|
  HRX.parse(io)
end
archive["foo.txt"] # => HRX::File.new("foo.txt", "FOO", nil, 1, 6)
archive["bar.txt"] # => HRX::File.new("bar.txt", "BAR", nil, 3, 6)
```

## Contributing

1. Fork it (<https://github.com/straight-shoota/hrx/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Johannes Müller](https://github.com/straight-shoota) - creator and maintainer
