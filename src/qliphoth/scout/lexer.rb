#coding:utf-8

module Qliphort
  module Scout

    class Rule
      attr_reader :name   # 规则名，要么为空(例外规则)，要么为字符串或标号
      attr_reader :regex  # 模式为正则式

      def initialize(name, regex)
        raise ArgumentError, '规则名必须是字符串或标号' unless name.nil? || name.is_a?(String) || name.is_a?(Symbol)
        raise ArgumentError, '模式必须是正则式' unless regex.is_a? Regexp
        @name, @regex = name, regex
      end
    end

    class Ruleset
      def initialize(&block)
        @rules, @ignore = [], []
        @unknown = Rule.new(nil, /^\w+$/) # 例外模式：捕捉到任意其他标号
        @ignore << /^\s+/ # 忽略模式：跳过空白
        yield self if block_given?
      end

      # 导入规则名称和模式
      def rule(name, regex)
        @rules << Rule.new(name, regex)
      end

      # 导入例外模式
      def ignore(regex)
        @ignore << regex
      end

      # 可否忽略
      def ignorable?(string)
        @ignore.each do |i|
          return true if string =~ i
        end
        return false
      end

      # 可否识别
      def identifiable?(string)
        @rules.each do |r|
          return true if string =~ r.regex
        end
        return true if string =~ @unknown.regex
        @ignore.each do |i|
          return true if string =~ i
        end
        return false
      end

      # 识别规则
      def identify(string, line)
        @rules.each do |r|
          return Token.new(r.name, string, line) if string =~ r.regex # 匹配规则返回标识符、原码和行号
        end
        return Token.new(@unknown.name, string, line) if string =~ @unknown.regex # 匹配其他模式返回nil、原码和行号
        return nil # 无法匹配
      end
    end 

    class Token
      attr_reader :name   # 标识符名称
      attr_reader :value  # 原码值
      attr_reader :line   # 行号

      def initialize(name, value, line)
        @name, @value, @line = name, value, line
      end

      def to_s
        "#{line} => #{name} : #{value}"
      end

      def to_hash
        {line: line, name: name, value: value}
      end

      def to_a
        [name, value, line]
      end
    end

    class Scout
      attr_accessor :ruleset
      attr_reader   :tokens

      def analyze(&block)
        instance_eval(&block)
      end

      def from_file(filepath=nil)
        raise ArgumentError, '文件路径必须为字符串' unless filepath.instance_of? String
        raise ArgumentError, '文件路径为空' if  filepath.empty?
        raise RuntimeError, '文件路径不存在' unless File.exists?(filepath)
        @tokens = scan(IO.read(filepath))
      end

      def from_string(source)
        raise ArgumentError, '文本必须为字符串' unless source.instance_of? String
        raise ArgumentError, '文本为空' if source.empty?
        @tokens = scan(source)
      end

      def token(params)
        @ruleset ||= Ruleset.new
        name  = params.keys.first   || nil
        regex = params.values.first || nil 
        @ruleset.rule(name, regex)
        @ruleset
      end

      # 扩展方法
      # name: 模块方法名,必须 path: 文件路径,可选
      def use(option)
        lang_file = ""
        option[:name] and lang_file = "qliphoth/scout/#{option[:name]}.rb"
        option[:path] and lang_file = option[:path]
        load(lang_file)
        instance_eval(&Language::send(option[:name]))
      rescue LoadError
        abort "方言路径未找到:#{lang_file}"
      end

      private 

      # 线性扫描
      def scan(input)
        previous = ''
        current  = ''
        tokens   = []
        new_line = 0
        line_num = 1

        input.each_char do |c|
          if c == "\n"
            new_line += 1
            line_num += 1 # 行号+1
            c = ' '
          else 
            new_line = 0
          end
          
          if !previous.empty? && ignorable?(previous) # 清空忽略模式的内容
            previous = ''
            current  = ''
          end

          current << c # 当前标识符新增一字符

          # 识别规则，如当前内容不可识别
          unless identifiable?(current)
            raise RuntimeError, "未知标识符`#{current}` 行号:#{line_num - new_line}" if previous.empty?
            token = identify(previous, line_num - new_line) # 将新增字符前的内容识别转为标识符
            raise RuntimeError, "未知标识符`#{previous}` 行号:#{line_num - new_line}" if token.nil? || token.name.nil?
            tokens  << token
            previous = c.clone
            current  = c.clone # 现有内容和新增前内容都以当前字符起重新计算
            next
          end

          previous = current.clone # 每轮新增字符识别后，新增前内容和当前内容保持一致
        end

        # 最后一个缓冲未识别的字符，如果可识别，识别并加入标识符列表
        unless previous.empty? || ignorable?(previous)
          token = identify(previous, line_num - new_line) 
          raise RuntimeError, "未知标识符`#{previous}` 行号:#{line_num - new_line}" if token.nil? || token.name.nil?
          tokens << token
        end

        return tokens
      end

      def ignorable?(string)
        @ruleset.ignorable?(string)
      end

      def identifiable?(string)
        @ruleset.identifiable?(string)
      end

      def identify(string, line)
        @ruleset.identify(string, line)
      end
    end

    module_function

    def define(&block)
      @lexer = Scout.new 
      @lexer.instance_eval(&block)
      @lexer
    end

    def reset!
      remove_instance_variable(:@lexer) if @lexer
    end

  end
end

class ::String
  def tokenize(option)
    # option={name: XXX, path: XXX/XXX.rb}
    @lexer ||= Qliphort::Scout.define do 
      use option
    end

    content = self
    @lexer.analyze do
      from_string content
    end

    @lexer.tokens
  end

  def to_tokens(mod=:natural)
    tokenize(mod)
  end
end
