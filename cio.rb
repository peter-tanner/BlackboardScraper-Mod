require 'fileutils'

ORIGINALPUTS = Proc.new { |x| puts x }

module CIO
    @text = []
    def self.save path
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, @text.join("\n") )
    end

    def self.push
        @indent ||= 0
        @indent += 1
    end

    def self.pop
        @indent ||= 1
        @indent -= 1
    end

    def self.puts text=""
        @indent ||= 0
        text = "#{(["\t"]*@indent).join("")}#{text}"
        ORIGINALPUTS.call text
        @text.push(text)
    end

    def self.with &block
        push
        yield
        pop
    end
end