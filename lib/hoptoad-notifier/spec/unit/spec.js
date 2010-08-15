JSpec.describe('Hoptoad', function() {
  before_each(function() {
    Hoptoad.API_KEY    = undefined;
    Hoptoad.NOTICE_XML = fixture('notice.xml');
  });

  describe('notify', function() {
    before_each(function() {
      var HTTP    = require('http');
      var context = JSpec.context = {
        xml: 'FAKE_XML',

        client: {
          request: function(method, path, headers) {}
        },

        request: {
          'end'   : function() {},
          'write' : function() {}
        }
      };

      stub(HTTP, 'createClient').and_return(context.client);
      stub(Hoptoad, 'generateXML').and_return(context.xml);
      stub(context.client, 'request').and_return(context.request);
    });

    after_each(function() {
      var HTTP = require('http');

      JSpec.context           = undefined;
      Hoptoad.ENVIRONMENT     = undefined;
      process.env['RACK_ENV'] = undefined;
      process.env['NODE_ENV'] = undefined;

      destub(HTTP);
      destub(Hoptoad);
    });

    it('should POST to "/notifier_api/v2/notices" with correct headers', function() {
      var
      context = JSpec.context;
      context.client.should.receive('request', 'once')
                           .with_args('POST',
                                      '/notifier_api/v2/notices',
                                      { 'Host'           : 'hoptoadapp.com',
                                        'Content-Type'   : 'text/xml',
                                        'Content-Length' : context.xml.length });

      Hoptoad.notify({});
    });

    it('should write the notice XML to the connection', function() {
      var
      context = JSpec.context;
      context.request.should.receive('write').with_args(context.xml);

      Hoptoad.notify({});
    });

    it('should end the request', function() {
      var
      context = JSpec.context;
      context.request.should.receive('end');

      Hoptoad.notify({});
    });

    it('should set key from HOTPOAD_API_KEY if present', function() {
      process.env['HOPTOAD_API_KEY'] = '1234abcd';

      Hoptoad.notify({});
      Hoptoad.API_KEY.should.eql('1234abcd');
    });

    it('should set environment from RACK_ENV if provided', function() {
      process.env['RACK_ENV'] = 'qa';

      Hoptoad.notify({});
      Hoptoad.ENVIRONMENT.should.eql('qa');
    });

    it('should set environment from NODE_ENV if provided', function() {
      process.env['NODE_ENV'] = 'staging';

      Hoptoad.notify({});
      Hoptoad.ENVIRONMENT.should.eql('staging');
    });

    it('should not overwrite environment from RACK_ENV or NODE_ENV if already set', function() {
      process.env['RACK_ENV'] = 'test';
      process.env['NODE_ENV'] = 'test';

      Hoptoad.environment = 'staging';
      Hoptoad.notify({});
      Hoptoad.ENVIRONMENT.should.eql('staging');
    });

    it('should default environment to production if not set', function() {
      Hoptoad.notify({});
      Hoptoad.ENVIRONMENT.should.eql('production');
    });
  });

  describe('environment=', function() {
    it('should update environment in notice XML', function() {
      var matcher = new RegExp('<environment-name>staging</environment-name>');

      Hoptoad.environment = 'staging';
      Hoptoad.NOTICE_XML.should.match(matcher);
    });

    it('should set ENVIRONMENT variable', function() {
      Hoptoad.environment = 'staging'
      Hoptoad.ENVIRONMENT.should.eql('staging');
    });
  });

  describe('key=', function() {
    it('should insert API key into notice XML', function() {
      var key     = 'EXAMPLE_KEY';
      var matcher = new RegExp('<api-key>' + key + '</api-key>');

      Hoptoad.key = key;
      Hoptoad.NOTICE_XML.should.match(matcher);
    });
  });

  describe('generateBacktrace', function() {
    it('should generate line XML elements for each backtrace line', function() {
      var backtraceXML = Hoptoad.generateBacktrace({
        stack : "  at Timeout.callback (file.js:10:1)\n" +
                "  at fakeFunction (file2.js:100:1)\n" +
                "at /Users/my/path/file.js:95:19"
      });

      backtraceXML.should.eql(['<line method="Timeout.callback" file="file.js" number="10" />', '<line method="fakeFunction" file="file2.js" number="100" />', '<line method="" file="/Users/my/path/file.js" number="95" />']);
    });

    it('should escape method and file attributes', function() {
      var backtraceXML = Hoptoad.generateBacktrace({
        stack : " at Timeout.<anonymous> (\'&\".js:10:1)"
      });

      backtraceXML.should.eql(['<line method="Timeout.&#60;anonymous&#62;" file="&#39;&#38;&#34;.js" number="10" />']);
    });

    it('should replace root path with [PROJECT_ROOT] in file path', function() {
      var path         = Hoptoad.root;
      var backtraceXML = Hoptoad.generateBacktrace({
        stack : " at exampleFunction (" + path + "/file.js:10:1)"
      });

      backtraceXML.should.eql(['<line method="exampleFunction" file="[PROJECT_ROOT]/file.js" number="10" />']);
    });

    it('should not include lines that do not match', function() {
      var backtraceXML = Hoptoad.generateBacktrace({
        stack : "  at Timeout.callback (file.js:10:1)\n" +
                "  node.js (file.js:1:2)"
      }).join('');

      backtraceXML.should_not.be_empty
      backtraceXML.should_not.include('node.js')
    });

    it('should support custom filters', function() {
      Hoptoad.backtrace_filters.push(/filter\.js/);

      var backtraceXML = Hoptoad.generateBacktrace({
        stack : "  at Timeout.callback (file.js:10:1)\n" +
                "  at Timeout.callback (filter.js:1:2)"
      }).join('');

      backtraceXML.should_not.be_empty
      backtraceXML.should_not.include('filter.js');
    });

    it('should handle non-string stack', function() {
      var backtraceXML = Hoptoad.generateBacktrace({
        stack : 1337
      });

      backtraceXML.should_not.be_empty
    });

    it('should handle nonexistent stack', function() {
      Hoptoad.generateBacktrace().should_not.be_empty
      Hoptoad.generateBacktrace({}).should_not.be_empty
    });
  });

  describe('generateXML', function() {
    before_each(function() {
      stub(Hoptoad, 'generateBacktrace')
        .and_return(['<line-1 />', '<line-2 />']);
    });

    after_each(function() {
      destub(Hoptoad, 'generateBacktrace');
    });

    it('should include project root', function() {
      var xml     = Hoptoad.generateXML({});
      var root    = process.cwd();
      var matcher = new RegExp('<project-root>' + root + '</project-root>');

      xml.should.match(matcher);
    });

    it('should include provided error type', function() {
      var xml     = Hoptoad.generateXML({ type : 'SOME_CRAZY_ERROR' });
      var matcher = new RegExp('<class>SOME_CRAZY_ERROR</class>');

      xml.should.match(matcher);
    });

    it('should include default error type if not provided', function() {
      var xml     = Hoptoad.generateXML({});
      var matcher = new RegExp('<class>Error</class>');

      xml.should.match(matcher);
    });

    it('should escape error type', function() {
      var xml     = Hoptoad.generateXML({ type : '"&\'<>' });
      var matcher = new RegExp('<class>&#34;&#38;&#39;&#60;&#62;</class>');

      xml.should.match(matcher);
    });

    it('should include provided error message', function() {
      var xml     = Hoptoad.generateXML({ message : 'Bad code.' });
      var matcher = new RegExp('<message>Bad code.</message>');

      xml.should.match(matcher);
    });

    it('should include default error message if not provided', function() {
      var xml     = Hoptoad.generateXML({});
      var matcher = new RegExp('<message>Unknown error.</message>');

      xml.should.match(matcher);
    });

    it('should escape error message', function() {
      var xml     = Hoptoad.generateXML({ message : '"&\'<>' });
      var matcher = new RegExp('<message>&#34;&#38;&#39;&#60;&#62;</message>');

      xml.should.match(matcher);
    });

    it('should include backtrace lines', function() {
      var xml     = Hoptoad.generateXML({});
      var matcher = new RegExp('<backtrace><line-1 /><line-2 /></backtrace>');

      xml.should.match(matcher);
    });

    it('should include URL and component', function() {
      var xml     = Hoptoad.generateXML({ url : '/', component : 'Home' });
      var matcher = new RegExp('<request><url>/</url><component>Home</component>.*</request>');

      xml.should.match(matcher);
    });

    it('should remove request if no URL and component provided', function() {
      var xml     = Hoptoad.generateXML({});
      var matcher = new RegExp('<request>.*</request>');

      xml.should_not.match(matcher);
    });

    it('should include action', function() {
      var xml     = Hoptoad.generateXML({ url : '/', component : 'Home', action : 'index' });
      var matcher = new RegExp('<request>.*<action>index</action>.*</request>');

      xml.should.match(matcher);
    });

    it('should include request params provided', function() {
      var matcher = new RegExp('<request>.*<params><var key="&#34;first">value</var><var key="second">&#60;whatever&#62;</var></params>.*</request>');
      var xml     = Hoptoad.generateXML({
        url        : '/',
        component  : 'Home',
        params     : {
          '"first' : 'value',
          second   : '<whatever>'
        }
      });

      xml.should.match(matcher);
    });

    it('should include session variables provided', function() {
      var matcher = new RegExp('<request>.*<session><var key="&#34;first">value</var><var key="second">&#60;whatever&#62;</var></session>.*</request>');
      var xml     = Hoptoad.generateXML({
        url        : '/',
        component  : 'Home',
        session    : {
          '"first' : 'value',
          second   : '<whatever>'
        }
      });

      xml.should.match(matcher);
    });

    it('should include cgi-data variables provided', function() {
      var matcher = new RegExp('<request>.*<cgi-data><var key="&#34;first">value</var><var key="second">&#60;whatever&#62;</var></cgi-data>.*</request>');
      var xml     = Hoptoad.generateXML({
        url        : '/',
        component  : 'Home',
        'cgi-data' : {
          '"first' : 'value',
          second   : '<whatever>'
        }
      });

      xml.should.match(matcher);
    });
  });
});
