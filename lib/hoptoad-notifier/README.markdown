# node-hoptoad-notifier

Report exceptions to Hoptoad from node.js.

## Example

    var
    Hoptoad = require('./lib/hoptoad-notifier').Hoptoad;
    Hoptoad.key = 'YOUR_API_KEY';

    process.addListener('uncaughtException', function(error) {
      Hoptoad.notify(error);
    });

## Configuration

### API Key (required)

You can set your project API key with the `HOPTOAD_API_KEY` environment
variable or dynamically with:

    Hoptoad.key = 'YOUR_API_KEY';

### Environment (optional)

The environment defaults to `production`. You can overwrite it by setting a
`RACK_ENV` or `NODE_ENV` environment variable. Additionally you can overwrite
it dynamically with:

    Hoptoad.environment = 'staging';

### Custom Backtrace Filters

Lines in the backtrace containing `hoptoad-notifier.js` are filtered by
default. You can add custom filters by pushing regular expressions on the
`backtrace_filters` variable:

    Hoptoad.backtrace_filters.push(/filter this line/);

## Testing

Run the [jspec](http://github.com/visionmedia/jspec) tests with:

    node spec/node.js

## License

The MIT License

Copyright (c) 2010 Tristan Dunn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
