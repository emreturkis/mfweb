
module Mfweb::InfoDeck

  class DeckMaker
    include Mfweb::Core
    include FileUtils
    attr_reader :output_dir, :js
    attr_accessor :code_server, 
       :asset_server, :google_analytics_file, :css_paths, :mfweb_dir, :js_dir
    def initialize input_file, output_dir
      @input_file = input_file
      @output_dir = output_dir
      @partials = {}
      @asset_server = AssetServer.new('.')
      @css_paths = %w[lib/mfweb/infodeck css] + [input_dir]
      @google_analytics_file = 'partials/footer/google-analytics.html'
      @mfweb_dir = "mfweb/"
      @css_out = StringIO.new
      @js_dir = File.join(@output_dir, 'js')
    end

    
    

    def run
      begin
        mkdir_p @output_dir, :verbose => false
        unless File.exists? @mfweb_dir + 'lib/mfweb/infodeck.rb'
          raise "unable to find mfweb library at <#{@mfweb_dir}>" 
        end
        @code_server = Mfweb::Core::CodeServer.new(input_dir + 'code/')
        @gen_dir = File.join('gen', input_dir)
        @js = JavascriptEmitter.new
        @build_collector = BuildCollector.new
        @root = Nokogiri::XML(File.read(@input_file)).root
        load_included_decks(@root)
        mkdir_p @gen_dir, :verbose => false
        import_local_ruby
        install_svg
        install @mfweb_dir + 'lib/mfweb/infodeck/public/*'
        install @mfweb_dir + 'lib/mfweb/infodeck/modernizr.custom.js'
        install_graphics
        install_jquery_svg_css
        install_js_components
        js_files = Dir[File.join(input_dir, 'js/*.js')]
        js_files.each {|f| install f}
        skeleton = DeckSkeleton.new
        skeleton.js_files = js_files.map{|f| f.pathmap("%f")}
        skeleton.maker = self
        skeleton.table_of_contents = table_of_contents
        coffee_glob = File.join(input_dir, 'js/*.coffee')
        unless Dir[coffee_glob].empty?
          sh "coffee -o #{@output_dir} -c #{coffee_glob}"
          skeleton.js_files += Dir[coffee_glob].map{|f| f.pathmap("%n.js")}
        end
        skeleton.js_files << 'contents.js'
        coffee_src = File.join(input_dir, 'deck.coffee') 
        if File.exist?(coffee_src)
          coffee_target = File.join(@output_dir, 'deck.js')
          sh "coffee -j #{coffee_target} -c #{coffee_src}"
          skeleton.js_files << coffee_target.pathmap('%f')
        end
        @root.css('partial').each {|e| add_partial e['id'], e}
        transform_slides
        build_css
        build_index_page skeleton
        generate_contents
        File.open(File.join(@output_dir, 'contents.js'), 'w') {|f| f << @js.to_js}
        generate_fallback
      rescue
        rm_r @output_dir
        raise $!
      end
    end 

    def logo 
      {src: 'mf-name-white.png', url: "http://martinfowler.com"}
    end

    def table_of_contents
      titles = @root.css('slide[title]')
      return nil if titles.empty?
      return titles.
        map{|e| "<p><a href='#%s'>%s</a></p>" % [e['id'], e['title']]}.
        join("\n")
    end

    def asset name
      @asset_server[name]
    end

    def build_index_page skeleton
      HtmlEmitter.open(output_file) do |html|
        skeleton.emit(html, title) do |html|
          html.div('init') do
            IndexTransformer.new(html, @root, self).render
          end
        end
      end
    end

    def title
      @root['title'] || "Untitled Infodeck"
    end

    def input_dir *path
      dir = @input_file.pathmap("%d/")
      File.join dir, *path
    end

    def output_dir *path
      File.join @output_dir, *path
    end

    def output_file
      output_dir 'index.html'
    end

    def load_included_decks aDeckRoot
      aDeckRoot.css('deck[src]').each do |d|
        inclusion = Nokogiri::XML(File.read(File.join(input_dir, d['src']))).root
        load_included_decks inclusion
        d.replace(inclusion)
      end
    end

    def install_svg
      Dir[File.join(input_dir, 'img/*.svg')].each do |f| 
         install_svg_file f
      end
      install File.join(@gen_dir, '*.svg')
    end
    
    def install_svg_file file_name
      SvgInstaller.new(file_name, @output_dir).run
    end

    def uri
      @output_dir.pathmap "%{build,}p"
    end

    def import_local_ruby
      ruby_files = Dir[input_dir + '/*.rb'] - [input_dir + '/rake.rb']
      ruby_files.each {|f| require f}
    end

    def install glob, subdir = nil
      files = Dir[glob]
      target = subdir ? File.join(@output_dir, subdir) : @output_dir
      mkdir_p target, :verbose => false
      files.each do |f|
        log.warn "missing file to install %s", f unless File.exist? f
        cp f, target, :verbose => false
      end
    end
    
    def install_graphics
      %w[png jpg].each {|ext| install(File.join(input_dir, 'img', '*.' + ext))}
    end

    def base_scss
        local_scss = File.join input_dir, 'deck.scss'
        return File.exist?(local_scss) ? local_scss : asset('infodeck.scss')
    end

    def build_css
      sass = Sass::Engine.new(File.read(base_scss), 
                              :syntax => :scss, :load_paths => css_paths)
      File.open("#{@output_dir}/infodeck.css", 'w') do |out| 
        out << sass.render
        return if @css_out.string.empty?
        out << "\n\n/*" + '-' * 50 + "*/\n\n"
        out << @css_out.string
      end
    end

    JQUERY_CSS_FILES = %w[jquery.svg.css]

    def install_jquery_svg_css
      install @mfweb_dir + 'vendor/jquerysvg/jquery.svg.css'
    end

    def js_svg_components
      %w[jquery.svg.min.js jquery.svgdom.min.js jquery.svganim.min.js]
        .map{|p| 'jquerysvg/' + p}
    end

    def js_components
      %w[jquery-1.7.2.min.js spin.js/spin.js q.js] + js_svg_components
    end

    def install_js_components
      mkdir_p @js_dir, :verbose => false
      js_components.each do |f| 
        src = File.join(@mfweb_dir, 'vendor', f)
        target = File.join(@js_dir, File.basename(f))
        FileUtils.install src, target
      end
    end

    def js_for_html
      js_components.map{|p| File.basename(p)} + %w[infodeck.js]
    end

    def img_file file_name
      gen_dir_file = @gen_dir + file_name
      return gen_dir_file if File.exists? gen_dir_file
      img_dir_file = input_dir + '/img/' + file_name
      return img_dir_file if File.exists? img_dir_file
      raise "unable to find image file for " + file_name
    end
    def add_partial key, anElement
      raise "duplicate partial definition for " + key if @partials.has_key? key
      @partials[key] = anElement
    end

    def partial key
      raise "missing partial " + key unless @partials.has_key? key
      @partials[key]
    end

    def task_dependencies
      rakefile = File.join input_dir, 'rake.rb'
      slide_files + [base_scss, rakefile]
    end
    def draft?
      'draft' == @root['status']
    end
    def allowed_fonts
      #should try to coordinate changes here with skeleton
      ['Inconsolata', 'Open Sans']
    end

    def transform_slides
      @root.css('slide').each do |anElement|
        output_file = "%s/%s.html" % [@output_dir, anElement['id']]
        HtmlEmitter.open(output_file) do |html|
          tr = transformer_class.new(html, anElement, self)
          tr.render
          @build_collector << tr.builds
        end
      end
    end

    def transformer_class
      DeckTransformer
    end

    def generate_contents
      contents = @root.css('slide').map{|e| e['id']}.
        map{|id| {'uri' => id + '.html'}}
      data = {'contents' => contents}
      @js << "function initialize_deck() {\n" 
      @js << "deck = new Infodeck(" << 
        data.to_json << 
        ");"
      @build_collector.emit_js(@js)
      @js << "};" << "\n"
      @js << "initialize_deck();" << "\n"
      @js << "window.deck.load();" 
    end

    def generate_fallback
      build_fallback_css
      HtmlEmitter.open(output_dir + '/fallback.html') do |html|
        headerTR = FallbackHeaderTransformer.new(html, @root, self)
        title = @root['title']
        fallback_skeleton.emit(html, title) do
          headerTR.render
          emit_dump html
        end
      end
    end
    def fallback_skeleton
      Site.skeleton
    end
    def emit_dump html
      html.div('text-dump') do
        html.p('intro') {html.text "The following is dump of the text in the deck to help search engines perform indexing"}
        FallbackDumpTransformer.new(html, @root, self).render
      end
    end
    def build_fallback_css
      sass = Sass::Engine.new(File.read(asset('fallback.scss')), 
                              :syntax => :scss, :load_paths => css_paths)
      File.open("#{@output_dir}/fallback.css", 'w') do |out| 
        out << sass.render
      end
    end

    def put_css aString
      @css_out << aString
    end
    def catalog
      Site.catalog
    end
    def catalog_key
      return File.basename(@output_dir)
    end
    def tags 
      if catalog && catalog[catalog_key]
        return catalog[catalog_key].tags
      else
        return []
      end
    end

    def self.compile_infodeck_js output, srcs, staging_dir
      mkdir_p staging_dir, QUIET
      mkdir_p output.pathmap('%d'), QUIET
      sh "coffee -o #{staging_dir} -c #{srcs}", QUIET
      sh "cat #{staging_dir}/*.js > #{output}", QUIET
    end

    def emit_metadata html
      md = Mfweb::Infodeck::Metadata.new(self, @root)
      MetadataEmitter.new(html, md).emit
    end
  end
end
