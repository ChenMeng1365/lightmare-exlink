module EasyLine
  module Handler
    module_function

    ######################################################################
    # Prefix                                                             #
    ######################################################################
    def path routes=[]
      @head ||= nil
      @head = routes.pop || '#/definitions'
      return @head
    end

    ######################################################################
    # Module                                                             #
    ######################################################################
    def moduel name
      @module ||= {}
      @module[name] ||= []
      @cur_mod = name
    end

    def common part
      @common = part
    end

    def push code
      @module[@cur_mod] ||= []
      @module[@cur_mod] << code
    end

    def fin
      unbind if @bind_num
      @head, @common, @cur_mod = nil, nil, nil
    end

    ######################################################################
    # Binding instance                                                   #
    ######################################################################
    def bind args=[]
      @bind_num ||= 0
      @list ||= []
      @list += args
      @bind_num = args.size
      return args.last
    end

    def unbind nums=[]
      @bind_num ||= 1
      @list ||= []; var = nil
      nums << @bind_num.to_s if nums.is_a?(Array) && nums.empty?
      nums.pop.to_i.times{ var = @list.pop }
      @bind_num = nil
      return var
    end

    ######################################################################
    # Evaluation                                                         #
    ######################################################################
    def eval expr, val, spc=nil
      hops = expr.split('/')
      if hops.size==1
        raw_mod = nil
        routes = hops
      elsif hops.size>1
        raw_mod = hops.shift
        routes = hops
      end
      def_mod = @cur_mod || raw_mod
      def_hed = @head=='#/definitions' ? nil : @head
      iter = ([def_mod, def_hed]+routes).compact.join('/')
      iter = iter.sub(@common, '') if @common
      @list ||= []
      @list.each{|item|iter = iter.sub('*/',"*[#{item}]/")}
      return {iter=>transform(val.pop)}.to_s
    end

    def transform atom
      atom.is_a_number? and return atom.proc_number
      atom.is_boolean?  and return atom.proc_boolean
      return atom
    end

    ######################################################################
    # Module accessor for parser                                         #
    ######################################################################
    def get_modules
      @module || {}
    end

    def clear_modules
      @module = {}
    end

  end
end