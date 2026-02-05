
module Whittle
  class Rule
    NULL_ACTION = Proc.new{}
    DUMP_ACTION = Proc.new{|input|input}

    attr_reader :name,:components,:action,:assoc,:prec

    # name:规则名称 components:规则列表，可以是终结符规则或简单的模式匹配
    def initialize(name, *components)
      @name       = name
      @components = components
      @action     = DUMP_ACTION
      @assoc      = :right
      @prec       = 0
      @components.each do |c|
        raise ArgumentError, "Unsupported rule component #{c.class}" unless Regexp === c || String === c || Symbol === c
      end
    end

    # 终结符为值非终结符为符号，推导到一条规则该规则必须有实现否则报错（重写改规则）
    def terminal?
      raise "Must be implemented by subclass"
    end

    # 遍历所有可能的规则分支，构建解析表
    # table:记录状态的散列表，键是hash化大数，值是状态 parser:解析器 context:解析状态的上下文记录
    def build_parse_table(table, parser, context)
      # 当前规则、标识符、状态
      state      = (table[context[:state]] ||= {})
      sym        = components[context[:offset]]
      rule       = parser.rules[sym]
      # 后续状态和位移索引
      new_offset = context[:offset] + 1
      new_state  = state.key?(sym) ? state[sym][:state] : nil # 如果当前标识符在状态机中存在，则根据状态机查找标识符的状态
      new_state ||= [self, new_offset].hash # 如果上述状态查不到，则生成一个新的状态（hash化）

      if sym.nil? # 当前状态的规则为空
        assert_reducible!(state, sym) # 检验状态可否推导，不可推导报错，可推导则推出结果
        state[sym] = {
          action: :reduce,
          rule:   self, # 该状态下规则为自身（应用该规则）
          prec:   context[:prec]
        }
        if context[:initial] # 上下文判断是否为初始状态，是则设置终结状态的规则为该规则自身
          state[:$end] = {
            action: :accept,
            rule:   self
          }
        end
      else # 该规则的组件之一
        raise GrammarError, "Unreferenced rule #{sym.inspect}" if rule.nil? # 语法解析判断是否报错
        new_prec = rule.terminal? ? rule.prec : context[:prec]
        if rule.terminal? # 规则解析为终结符
          state[sym] = {
            action: :shift,
            state:  new_state, # 生成新状态
            prec:   new_prec,  # 取该规则的优先级
            assoc:  rule.assoc # 取该规则的结合律
          }
        else # 规则解析为非终结符
          state[sym] = {
            action: :goto,
            state:  new_state
          }
          # 对该规则递归构建解析表
          rule.build_parse_table(
            table,
            parser,
            {
              state:  context[:state], # 下溯上下文的状态
              seen:   context[:seen],
              offset: 0,
              prec:   0
            }
          )
        end
        # 该规则解析完后，继续递归构造新状态的解析表
        build_parse_table(
          table,
          parser,
          {
            :initial => context[:initial],
            :state   => new_state,
            :seen    => context[:seen],
            :offset  => new_offset,
            :prec    => new_prec
          }
        )
      end

      resolve_conflicts(state) # 处理状态变化，状态为推导规则则删除所有优先级小于它的或左结合转移规则，没有推导规则则状态为空
    end

    # 设置规则如何处理
    def as(preset=nil, &block)
      tap do
        case preset
        when :value
          @action = DUMP_ACTION # 原样回传
        when :nothing
          @action = NULL_ACTION # 跳过处理
        when nil
          raise ArgumentError, "Rule#as expected a block, not none given" unless block_given?
          @action = block # 绑定处理块
        else
          raise ArgumentError, "Invalid preset #{preset.inspect} to Rule#as"
        end
      end
    end

    # 跳过处理
    def skip!
      as(:nothing)
    end

    # 设置结合律，:left、:right(默认)和:nonassoc
    def %(assoc)
      raise ArgumentError, "Invalid associativity #{assoc.inspect}" unless [:left, :right, :nonassoc].include?(assoc)
      tap{@assoc=assoc}
    end

    # 设置规则优先级，数值越大越优先，默认为0
    def ^(prec)
      raise ArgumentError, "Invalid precedence level #{prec.inspect}" unless prec.respond_to?(:to_i)
      tap{@prec=prec.to_i}
    end

    private

    # 处理状态冲突
    def resolve_conflicts(instructions)
      if r = instructions.values.detect{|i|i[:action]==:reduce} # 找出状态的规则动作为推导的**一个**状态
        instructions.reject! do |s, i| # 动作为转移 且 (优先级小于推导规则优先级 或 优先级和推导规则优先级相等但是左结合) 的规则
          ((i[:action] == :shift) &&
           ((r[:prec] > i[:prec]) ||
            (r[:prec] == i[:prec] && i[:assoc] == :left)))
        end # 将这样的规则的状态从状态上下文中剔除
      end # 如果没有找到推导规则的状态那么就返回nil
    end

    # 检验状态是否可推导（此时规则为nil）
    def assert_reducible!(instructions, sym)
      if instructions.key?(sym) && !instructions[sym][:rule].equal?(self) # 状态存在该规则且该状态的规则不为该规则自身
        message = <<-END.gsub(/(^|$)\s+/m, " ")
          Unresolvable conflict found between rules
          `#{name.inspect} := #{components.inspect}`
          and
          `#{instructions[sym][:rule].name.inspect} := #{instructions[sym][:rule].components.inspect}`
          (restructure your grammar to prevent this)
        END
        raise GrammarError, message # 报语法错
      end
    end
  end
  
  class RuleSet
    include Enumerable

    def initialize(name, terminal=false)
      @name       = name
      @rules      = []
      @terminal   = terminal # 默认非终结符，可以添加规则
    end

    # 迭代所有规则
    def each(&block)
      @rules.each(&block)
    end

    # 根据自身是终结符/非终结符添加规则
    # components:符号、字符串或正则式
    def [](*components)
      klass = terminal? ? Terminal : NonTerminal
      klass.new(@name, *components).tap{|rule|@rules << rule}
    end

    # 解析器对每条规则的应用，匹配则返回标识符，不匹配返回nil
    # source:输入字符串 offset:当前位移 line:当前行号
    def scan(source, offset, line)
      each do |rule|
        token = rule.scan(source, offset, line)
        token and return token
      end
      nil
    end

    # 递归构建解析表
    def build_parse_table(table, parser, context)
      return table if context[:seen].include?([context[:state], self])
      context[:seen] << [context[:state], self]
      table.tap do
        each do |rule|
          rule.build_parse_table(table, parser, context)
        end
      end
    end

    # 规则集是否是终结符
    def terminal?
      @terminal
    end

    # 规则集是否是非终结符
    def nonterminal?
      !terminal?
    end

    # 规则集的优先级
    def prec
      terminal? ? @rules.first.prec : 0
    end

    # 规则集的结合律
    def assoc
      terminal? ? @rules.first.assoc : :right
    end
  end
  
  # 终结符规则
  class Terminal < Rule
    def terminal?
      true
    end

    # 解析器扫描匹配终结符，跳过非终结符
    # source:扫描字符串 offset:扫描当前索引 line:匹配到标识符时解析器所在行数
    # return:匹配式样@pattern返回扫描结果，匹配不上返回nil
    def scan(source, offset, line)
      if match = source.match(@pattern, offset)
        {
          rule:      self,
          value:     match[0],
          line:      line + match[0].count("\r\n", "\n"),
          discarded: @action.equal?(NULL_ACTION)
        }
      end
    end

    private

    def initialize(name, *components)
      raise ArgumentError, "Rule #{name.inspect} is terminal and can only have one rule component" unless components.size == 1
      super()
      pattern = components.first
      @pattern = Regexp.new("\\G#{ ( pattern.kind_of?(Regexp) ? pattern : Regexp.escape(pattern) ) }")
    end
  end

  # 非终结符规则
  class NonTerminal < Rule
    def terminal?
      false
    end
  end
end
