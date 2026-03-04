module EasyLine

  module_function

  def runner format=:json
    return %q{#!/usr/bin/env ruby
#coding:utf-8
require 'lightmare-exlink'

begin # make instance
  inst = XiaoLong.gen_root
  [
    ((target))
  ].each do|item|
    path, val = item.keys.first, item.values.first
    current = XiaoLong.asym path.sub('#/definitions/',''), inst
    current.val = val
  end
  File.write "((name)).json",JSON.pretty_generate(inst.to_doc(lambda{|n|n.val}))
end} if format==:json
    return %q{#!/usr/bin/env ruby
#coding:utf-8
require 'lightmare-exlink'

begin # make instance
  inst = XiaoLong.gen_root
  [
    ((target))
  ].each do|item|
    path, val = item.keys.first, item.values.first
    current = XiaoLong.asym path.sub('#/definitions/',''), inst
    current.val = val
  end
  inst.name='config'
  File.write "((name)).xml",newstr=inst.to_netconf
end} if format==:xml
  end

  ######################################################################
  # Handle - orchestrates Handler operations                           #
  ######################################################################
  def handle src, spc
    src.inject([]) do|dst, s|
      f,a = s
      # sending message or evaluating
      evaluted = EasyLine::Handler.respond_to?(f) ? EasyLine::Handler.send(f, a) : EasyLine::Handler.eval(f, a, spc)
      evaluted ? (dst << evaluted) : dst
    end
  end

end

class String
  def is_a_number?
    /^\-?\d+(\.\d+)?(e\-?\d+)?$/.match(self)
  end

  # if not a number, no transform
  def proc_number
    is_a_number? ? (self.include?('.') || self.include?('e') ? self.to_f : self.to_i) : self
  end

  def is_boolean?
    ['true','false'].include?(self.downcase)
  end

  def proc_boolean
    is_boolean? ? eval(self.downcase) : self
  end
end