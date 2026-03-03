#coding:utf-8

require 'yaml'
require 'json'

module EnData
  extend self
  
  def load
    @__EnData__ ||= DATA.read
    return @__EnData__
  end
  
  # ['username'@EnData 'workpath']$ 'command' 'scriptname' 'argument1#' ...
  def parse data=@__EnData__
    @__datalist__ = {}
    temp = {
      'user' => '',
      'path' => '',
      'handler' => '',
      'name' => '',
      'arguments' => [],
      'context' => []
    }
    data.split("\n").each do|line|
      if matcher = /^\[[\w|\s]*\@endata[\w|\s|\/|\~]*\]\$/.match(line)
        @__datalist__[temp['name']] = temp
        front, back = line.split("@endata")
        usr = front.sub("[",'').strip
        pwd = back.split("]")[0].strip
        cmd = back.split("]$")[-1].split(" ")
        handler, name, arguments = cmd[0], cmd[1], cmd[2..-1]
        context = ''
        temp = {
          'user' => usr,
          'path' => pwd,
          'handler' => handler,
          'name' => name,
          'arguments' => arguments,
          'context' => []
        }
      else
        temp['context'] << line
      end
    end
    @__datalist__[temp['name']] = temp
    return @__datallist__
  end
  
  def select options={}
    if name = options[:name]
      @__datalist__[name]
    else
      sets = @__datalist__.values
      options.each do|key, val|
        sets = sets.select{|s|s[key.to_s]==val.to_s}
      end
      sets.first
    end
  end
  
  def source script
    context = script['context'].join("\n")
    case script['handler']
    when 'ruby'
      context
    when 'yaml'
      YAML.load context
    when 'json'
      JSON.parse context
    else # plaintext
      context
    end
  end
  
  # ruby inline
  def run scripts=nil, &script_block
    scripts ? self.module_eval(scripts) : self.module_eval(&script_block)
  end
end


=begin
EnData.load
EnData.parse

ruby = EnData.run EnData.source EnData.select name: 'code'
yaml = EnData.source EnData.select handler: 'yaml'
json = EnData.source EnData.select handler: :json

main = EnData.run do
  puts ruby
  pp yaml
  pp json
end

__END__
[a@endata ~]$ruby code
number = 1+1
迪兰 = rand.round(2)

[b@endata / ]$yaml hank
hank:
  - code
  - debug
  - deploy
hazel:
  blue
  
[c@endata /home/base]$ json coco
[{
  "dare": 100.0,
  "gale": [70,50,13,"outfit"]
}]
=end