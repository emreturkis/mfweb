module Mfweb::Article

class ArticleMaker < Mfweb::Core::TransformerPageRenderer
  attr_accessor :pattern_server, 
    :code_server, :bib_server, :footnote_server, :catalog, :author_server
  def initialize infile, outfile, skeleton = nil, transformerClass = nil
    @catalog = Mfweb::Core::Site.catalog
    @author_server = Mfweb::Core::Site.author_server
    super(infile, outfile, transformerClass, skeleton)
    puts "#{@in_file} -> #{@out_file}" #TODO move to rake task
    @pattern_server = PatternServer.new
    @code_server = Mfweb::Core::CodeServer.new
    @bib_server = Bibliography.new
    @footnote_server = FootnoteServer.new(infile)
    @code_dir = './'
  end

  def load
    super
    @is_draft = ('draft' == @root['status'])
    @pattern_server.load
    resolve_includes @root
    @skeleton ||=  Mfweb::Core::Site.
      skeleton.with_css('article.css').
      with_banner_for_tags(tags)
    @skeleton = @skeleton.as_draft if draft?
  end

  def draft?
    @is_draft
  end

  def render_body
    @transformer.render
  end

  def transformer_class
    return @transformer_class if @transformer_class
    return case @root.name
           when 'paper'   then PaperTransformer
           when 'pattern' then PatternHandler
           else fail "no transformer for #{@in_file}"
           end
    
  end


  def catalog_ref
    return @root['catalog-ref'] || File.basename(@out_file, '.html')
  end

  def tags
    # some old papers are not registered in catalog
    if @catalog && @catalog[catalog_ref]
      return @catalog[catalog_ref].tags
    else
      return []
    end
  end
  def resolve_includes aRoot
    aRoot.css('include').each do |elem|
      inclusion = Nokogiri::XML(File.read(input_dir(elem['src']))).root
      resolve_includes inclusion
      elem.replace inclusion.children
    end
  end
  def author key
    @author_server.get key
  end
end


end
