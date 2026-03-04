module EasyLine
  module Handler
    module_function

    def path routes
      @head = routes.pop || '#/definitions'
      return nil
    end

    def bind args
      @bind_num ||= 0
      @list ||= []
      @list += args
      @bind_num = args.size
      return nil
    end

    def unbind nums=[]
      @bind_num ||= 1
      @list ||= []
      nums << @bind_num.to_s if nums.is_a?(Array) && nums.empty?
      nums.pop.to_i.times{ @list.pop }
      return nil
    end

    def eval expr, val, spc
      @list ||= []
      iter = [@head, (spc ? '((root))' : expr.split('/')[0]), expr.split('/')[1..-1].join('/')].compact.join('/') # use ((root)) instead of spec-module-name
      @list.each{|item|iter = iter.sub('*/',"*[#{item}]/")}
      return {iter=>transform(val.pop)}.to_s
    end


  end
end