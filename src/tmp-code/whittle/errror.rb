module Whittle
  class Error < RuntimeError
  end

  # 语法错误
  class GrammarError < Error
  end

  # 词法分析未匹配token错误
  class UnconsumedInputError < Error
  end

  # ParseError is raised if the parse encounters an unexpected token in the input.
  #
  # You can extract the line number, the expected input and the received input.
  class ParseError < Error
    attr_reader :line
    attr_reader :expected
    attr_reader :received

    # Initialize the ParseError with information about the location
    #
    # @param [String] message
    #   the exception message displayed to the user
    #
    # @param [Fixnum] line
    #   the line on which the unexpected token was encountered
    #
    # @param [Array] expected
    #   an array of all possible tokens in the current parser state
    #
    # @param [String, Symbol] received
    #   the name of the actually received token
    def initialize(message, line, expected, received)
      super(message)

      @line     = line
      @expected = expected
      @received = received
    end
  end


end
