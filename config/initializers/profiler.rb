class Profiler
  def self.profile(output_filename = "prof.html", &block)
    require 'ruby-prof'
    block_result = nil
    result = RubyProf.profile { block_result = block.call }
    printer = RubyProf::GraphHtmlPrinter.new(result)
    File.open(output_filename, "w") { |f| printer.print(f) }
    block_result
  end
end
