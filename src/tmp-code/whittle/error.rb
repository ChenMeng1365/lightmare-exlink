module Whittle
  class Error < RuntimeError
  end

  # 语法错误
  class GrammarError < Error
  end

  # 词法分析未匹配token错误
  class UnconsumedInputError < Error
  end

  # 非预期标识符错误
  class ParseError < Error
    attr_reader :line
    attr_reader :expected
    attr_reader :received

    # message:异常信息 line:异常标识符行号 expected:解析器预期的当前标识符状态数组 received:实际接收的标识符名称
    def initialize(message, line, expected, received)
      super(message)
      @line = line
      @expected = expected
      @received = received
    end
  end
  
  # Since parse error diagram the region where the error occured,
  # this logic is split out from the main Parser
  class ParseErrorBuilder
    class << self
      # Generates a ParseError for the given set of error conditions
      #
      # A ParseError always specifies the line nunber, the expected inputs and
      # the received input.
      #
      # If possible, it also draw a diagram indicating the point where the
      # error occurred.
      #
      # @param [Hash] state
      #   all the instructions for the current parser state
      #
      # @param [Hash] token
      #   the unexpected input token
      #
      # @param [Hash] context
      #   the current parser context, providing line number, input string + stack etc
      #
      # @return [ParseError]
      #   a detailed Exception to be raised
      def exception(state, token, context)
        region   = extract_error_region(token[:offset], context[:input])
        expected = extract_expected_tokens(state)
        message  = <<-ERROR.gsub(/\n(?!\n)\s+/, " ").strip
          Parse error:
          #{expected.count > 1 ? 'expected one of' : 'expected'}
          #{expected.map { |k| k.inspect }.join(", ")}
          but got
          #{token[:name].inspect}
          on line
          #{token[:line]}.
        ERROR

        unless region.nil?
          region = "\n\n#{region}"
        end

        ParseError.new(message + region.to_s, token[:line], expected, token[:name])
      end

      private

      def extract_error_region(offset, input)
        return if offset.nil?

        # FIXME: If anybody has a cleaner way to insert the ^ marker, please do :-)
        width        = 100
        start_offset = [offset - width, 0].max
        end_offset   = offset + width
        before       = input[start_offset, [offset, width].min]
        after        = input[offset, width]
        before_lines = "~#{before}~".lines.to_a
        after_lines  = "~#{after}~".lines.to_a

        before_lines.first.slice!(0)
        before_lines.last.chop!

        after_lines.first.slice!(0)
        after_lines.last.chop!

        region_before = before_lines.pop
        region_after  = after_lines.shift
        error_line = region_before + region_after

        padding = if region_before.length > 5
          (" " * (region_before.length - 5)) + " ... "
        else
          " " * region_before.length
        end

        marker = "#{padding}^ ... occurred here\n\n"

        unless error_line =~ /[\r\n]\Z/
          marker = "\n#{marker}"
        end

        "#{error_line}#{marker}"
      end

      def extract_expected_tokens(state)
        state.select { |s, i| [:shift, :accept].include?(i[:action]) }.keys
      end
    end
  end
end