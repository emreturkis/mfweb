module Mfweb::Core
require 'uri'
module HtmlUtils
  def a_ref uri, text
    if uri
      "<a href = #{URI.encode(uri)}>#{text}</a>"
    else
      text
    end
  end
  def self.dot_sep
    "&nbsp;&middot; "
  end
  def dot_sep
    HtmlUtils::dot_sep
  end
  def include fileName
    include_path.each do |dir|
      f = File.join(dir, fileName)
      return include_abs(f) if File.exists? f
    end
    raise "unable to find #{fileName} in #{include_path.join(' ')}"
  end
  def include_abs fileName
    case File.extname(fileName)
    when ".html" then File.read(fileName)
    when ".markdown", ".md"
      require 'kramdown'
      mdown = ERB.new(File.read(fileName)).result(binding)
      Kramdown::Document.new(mdown).to_html
    when ".haml"
      require 'haml'
      Haml::Engine.new(File.read(fileName)).render(self)
    else 
      raise "unable to include #{fileName}"
    end
  end
  def include_path
    %w[. .. ../../gen gen]
  end

  def custom_banner args
    photo_fn = args[:photo_fn] || 'banner.png'
    output = StringIO.new
    template_file = File.join(site_root, 'gen/banner.html.erb')
    output << ERB.new(File.read(template_file)).result(binding)
    return output.string
  end

  def site_root
    Dir.pwd
  end

  def pick_photo arg
    tags = Array(arg)
    m = lambda {|regexp| tags.any? {|t| t.match(regexp)}}
    return case
           when m.call(/noSQL/), m.call(/database/)
             '../img/mesa.png'
           when m.call(/refactoring/) then '../img/tate.png'
           when m.call(/domain specific language/) 
             '../img/ironbridge.jpg'
           when m.call(/bad thing/) then '../img/croc.png'
           when m.call(/agile/) then '../img/poetta.png'
           when m.call(/extreme programming/) then '../img/poetta.png'
           when m.call(/design/) then '../img/zakim.png'
           when m.call(/architecture/) then '../img/zakim.png'
           else 'banner.png'
           end
  end




  # def generate_line width
  #   # handy for trying out text line widths
  #   num_alphabets = width / 26 + 1
  #   base = []
  #   num_alphabets.times {base += ('a'..'z').to_a}
  #   return base[0..width]
  # end


  def amazon asin, text
    amazon_pre(asin) + text + amazon_post
  end

  def amazon_pre asin
    %[<a href = "http://www.amazon.com/gp/product/#{asin}?ie=UTF8&amp;tag=martinfowlerc-20&amp;linkCode=as2&amp;camp=1789&amp;creative=9325&amp;creativeASIN=#{asin}">]
  end
  def amazon_post 
    '</a><img src="http://www.assoc-amazon.com/e/ir?t=martinfowlerc-20&amp;l=as2&amp;o=1&amp;a=0321601912" width="1" height="1" border="0" alt="" style="width: 1px !important; height: 1px !important; border:none !important; margin:0px !important;"/>'
  end

def informit isbn, text
  %[<a href="http://click.linksynergy.com/fs-bin/click?id=tEHDyk1X8h0&amp;subid=&amp;offerid=145238.1&amp;type=10&amp;tmpid=3559&amp;RD_PARM1=http%253A%252F%252Fwww.informit.com%252Fstore%252Fproduct.aspx%253Fisbn%253D#{isbn}">#{text}</a>
<img alt="icon" width="1" height="1" src="http://ad.linksynergy.com/fs-bin/show?id=tEHDyk1X8h0&amp;bids=145238.1&amp;type=10">]
end

  def css fileName
    %[<link href = "#{fileName}" rel = "stylesheet" type = "text/css"/>]
  end

  def emit_shares lede, url
    twitter = "https://twitter.com/intent/tweet?url=%s&text=%s" % [url, lede]
    facebook = "https://facebook.com/sharer.php?u=%s" % [url]
    google = "https://plus.google.com/share?url=%s" % [url]
    @html.p('shares') do
      @html.span('label') {@html.text "Share: "}
      @html.a_ref(twitter, title: "Share on Twitter") {@html.img "/t_mini-a.png"}
      @html.a_ref(facebook, title: "Share on Facebook") {@html.img "/fb-icon-20.png"}
      @html.a_ref(google, title: "Share on Google Plus") {@html.img "/gplus-16.png"}
    end
  end


end
end
