require "ostruct"
require "optparse"

module Frasier

  class CLI
    def self.parse(args)
      options = OpenStruct.new
      options.number_of_words = 5

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: frasier [options]"

        opts.on("-n", "--number [NUMBER]", Integer, "Generate passphrase with <n> words") do |n|
          options.number_of_words = n.to_i
        end

        opts.on("-l", "--list-books", "List available books") do |list|
          books = Library.new.books
          longest_title = books.map(&:title).max.length
          puts books.map{|b| "      %s - %s" % [b.title.ljust(longest_title), File.basename(b.path)]}
          exit
        end

        opts.on("-b", "--book [NAME]", String, "Specify book to generate from") do |book|
          lib = Library.new
          unless book && lib.book_with_name(book)
            puts "I don't know that book, did you mean:"
            longest_title = lib.books.map(&:title).max.length
            puts lib.books.map{|b| "      %s - %s" % [b.title.ljust(longest_title), File.basename(b.path)]}
            exit
          end
          options.book = book
        end

        opts.on("-i", "--info", "Show entropy info") do |info|
          options.info = info
        end

        opts.on("-S", "--no-whitespace", "Replace whitespace with random characters") do |bool|
          options.no_whitespace = !bool
        end

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.on_tail("--version", "Show version") do
          puts Frasier::VERSION
          exit
        end
      end

      if Library.new.books.empty?
        puts <<BLURB

Please install some books into ~/.config/frasier/
Example:
      curl -L http://www.gutenberg.org/ebooks/8164.txt.utf-8 -o ~/.config/frasier/my_man_jeeves
BLURB
        exit
      end

      opts.parse!(args)
      options
    end

    def initialize(options)
      library = Library.new
      @book = library.book_with_name(options.book) if options.book
      @book = library.random_book unless @book
      number_of_words = options.number_of_words

      @generator = Generator.new(@book.dice_word_list, number_of_words)
      print_passphrase(options.info, !!options.no_whitespace)
    end

    def print_passphrase(info = true, no_whitespace = false)
      if no_whitespace
        phrase = @generator.passphrase_without_whitespace
      else
        phrase = @generator.passphrase
      end
      # Try to copy it
      copy(phrase) if copy_command
      if info
        number_of_guesses = 100000
        duration_in_years = (@generator.duration_to_guess(number_of_guesses)/60.0/60.0/24.0/360.0).round(2)
        puts "From: #{@book.title}"
        puts "Bits of entropy: #{@generator.bits_of_entropy}"
        puts "At 100 000 guesses/s, it would take %s years to guess" % duration_in_years
        puts ""
      end
      puts red(phrase)
    end

    def copy_command
      os = RbConfig::CONFIG['host_os']
      return 'pbcopy' if os =~ /mac|darwin/
      return 'xclip -selection clipboard' if os =~ /linux|bsd|cygwin/
      nil
    end

    def copy(value)
      return unless copy_command
      begin
        IO.popen(copy_command,"w") {|cc|  cc.write(value)}
        value
      rescue Errno::ENOENT
      end
    end

    def red(s)
      "\e[31m#{s}\e[0m"
    end
  end
end
