BUILD_DIR = 'build/test/'
MFWEB_DIR = './'

require 'mfweb/infodeck/infodeck.rake'



namespace :infodeck do
  desc "builds infodeck mocha test runner"
  task :mocha => [:clobber, "^test", :js] do
    log "building test deck for javascript tests"
    require_relative 'mochaPageRenderer'
    require_relative 'mochaMaker'
    src = 'test/infodeck/mocha/'
    target = BUILD_DIR + 'mocha/'
    maker = MochaMaker.new src, target
    maker.run
  end

  desc "runs server for infodeck mocha page"
  task :mocha_server do
    puts "in #{Dir.pwd}"
    require 'webrick'
    include WEBrick

    port = 2929

    puts "URL: http://#{Socket.gethostname}:#{port}"
    mime_types = WEBrick::HTTPUtils::DefaultMimeTypes
    mime_types.store 'js', 'application/javascript'
    mime_types.store 'svg', 'image/svg+xml'

    s = HTTPServer.new(:Port            => port,
                       :MimeTypes => mime_types,
                       :DocumentRoot    => 'build/test')

    trap("INT"){ s.shutdown }
    s.start   
  end

end
