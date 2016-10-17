require 'rexml/document'
class Doremi
  Domain = []
  def initialize(xml, binding = TOPLEVEL_BINDING)
    @xml     = xml
    @doc     = REXML::Document.new(@xml)
    @binding = binding
    @ns      = {}
    registers
  end

  def registers
    register "doremi" do |node|
      eval("self", node.binding).send(node.name, node)
    end
    register 'react-like' do |node|
      #node is a root
      a = node.children
      b = a.map.with_index{|x, i|      
        case x 
        when REXML::Text
          x
        when REXML::Element
          " ([__node.domain.runNode(__node.children[" + i.to_s + "], __node.binding), __node.args.pop][1]) "
        when nil
          ""
        end
      }.join("")
      eval("__node = nil; lambda{|node| __node = node}", node.binding).call(node)
      eval b, node.binding
    end
  end

  def register(a, b = nil, &c)
    @ns[a] = b || c
  end

  def ns(a)
   if @ns.include?(a)
     @ns[a]
   else
     raise "can't find namespace #{a}"
   end
  end

  def push(obj)
    @stack.push obj
  end

  def pop
    @stack.pop
  end

  def top
    @stack.last
  end

  def parent
    @stack[-2]
  end

  def run
    Domain.push self
    @stack = []
    runNode @doc.children[1], @binding
    @doc.children[1].result
  ensure
    Domain.pop
  end  

  def runNode(node, bd)
    node.doremi self, bd
  end
end

module REXML
  class Element
    attr_accessor :args, :block, :result, :parent, :domain, :binding
    def doremi(domain, binding) 
      self.parent = domain.top
      self.domain = domain
      domain.push self
      self.args  = []
      self.block = nil
      self.binding = binding
      if self.namespace != ""
        return domain.ns(self.namespace).call(self)
      end
      children.each{|x|
        domain.runNode x, self.binding
      }
      a = self.attributes.map{|k, v| [k, v]}.to_h
      if a.empty? 
        self.result = eval("self", self.binding).send(name, *args, &block)
      else

        self.result = eval("self", self.binding).send(name, *args, a, &block)
      end
      parent.args.push self.result if parent
      domain.pop
    end
  end

  class Text
    attr_accessor :binding
    def doremi(domain, binding)
      self.binding = binding
      domain.top.args.push(eval(to_s, binding)) if to_s!=""
    end
  end
end

def register_namespace(a, b = nil, &c)
  Doremi::Domain.last.register a, b, &c
end


def seq(*, last) 
  last 
end

def id(a)
  a
end