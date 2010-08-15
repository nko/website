require.paths.unshift('spec', './spec/lib', 'lib');

require('jspec');
require('unit/spec.helper');

Hoptoad = require('hoptoad-notifier').Hoptoad;

JSpec
  .exec('spec/unit/spec.js')
  .run({
    reporter     : JSpec.reporters.Terminal,
    fixturePath  : 'spec/fixtures',
    failuresOnly : true
  })
  .report();
