#coding:utf-8

class Miló(object):
    leafs = []

    def __init__(self, name :str, type:str=None, value=None, parent=None, attr:dict={}, elem:list=[]):
        self.name_ = name
        self.attr_ = attr
        self.type_ = name if not type else type
        self.elem_ = []; self.load(elem)
        self.value_ = value
        self.parent_= None if not parent else parent
    # end def initialize

    @property
    def name(self): return self.name_

    @property
    def type(self): return self.type_

    @property
    def attr(self): return self.attr_

    @property
    def elem(self): return self.elem_

    @property
    def value(self): return self.value_

    @property
    def parent(self): return self.parent_

    @name.setter
    def name(self, name: str): self.name_=name; return self.name_

    @type.setter
    def type(self, type: str): self.type_=type; return self.type_

    @attr.setter
    def attr(self, attr: dict): self.attr_=attr; return self.attr_

    @elem.setter
    def elem(self, elem: list): self.elem_=elem; return self.elem_

    @value.setter
    def value(self, value): self.value_=value; return self.value_

    @parent.setter
    def parent(self, parent): self.parent_=parent; return self.parent_

    def merge(self, l:dict={}, **kvs): self.attr_.update(l);self.attr_.update(kvs); return self.attr_

    def load(self, elem: list): self.elem_ += list(filter(lambda e:type(e) is type(self), elem)); return self.elem_

    def trail(self, record=[]):
        record.insert(0, self)
        if self.parent: return self.parent.trail(record)
        else: return record
    # end def trail

    def depth(self, number=1):
        subs = []
        for k in self.attr.keys():
            sn = self.attr[k].depth(number+1)
            subs.append(sn)
        for e in self.elem:
            sn = e.depth(number+1)
            subs.append(sn)
        if not subs: return number
        return max(subs)
    # end def depth

    def todoc(self, fun='value', depth=1):
        # if ( depth > 3 ): return '...'

        pdoc, ndoc = {}, []
        if self.attr:
            for key in self.attr.keys(): pdoc.update({key: self.attr[key].todoc(fun,depth+1)})
            if pdoc: return pdoc

        if self.elem:
            for e in self.elem: ndoc.append(e.todoc(fun,depth+1))
            if ndoc: return ndoc

        # if (self.type=='value'): return getattr(self, fun)
        return self.value
    # end def todoc

    def dedoc(self, doc):
        leafs = []
        if not self.type: self.type = 'node'
        if type(doc) is dict:
            for key in doc.keys():
                child = Miló(key)
                self.merge({key: child})
                child.parent = self
                child.dedoc(doc.get(key))
                # print( f'{self.name}:{self.type} >--({key})--> {child.name}:{child.type}\n' )
        if type(doc) is list:
            self.type = 'list'
            counter = 1
            for subdoc in doc:
                child = Miló(f'*[{id(subdoc)}]', type='item', parent=self)
                self.elem.append(child)
                child.dedoc(subdoc)
                counter += 1
                # print( f'{self.name}:{self.type} +--({counter})--> {child.name}:{child.type}\n' )
        if type(doc) in [int, float, bool, str]:
            self.type = 'value'
            self.value = doc
            Miló.leafs.append(self)
            # tracerail = [ node.name for node in self.trail([])]; print(f'{"/".join(tracerail)} = {self.value}')
            # print( f'{self.name}:{self.type} >====> {self.value}:{self.type}({type(self.value)})\n' )
    # end def dedoc

    def asym(self, proleaf):
        keys, path, leafvalue, leaftype = proleaf
        hops = path.split('/')
        for hop in hops:
            if (hop==''): current = self; continue
            if ('*' in hop):
                current.type = 'list'
                key = keys[0]
                items = list(filter(lambda e: e.name==f'*[{key}]', current.elem))
                if not items:
                    item = Miló(f'*[{key}]',type='item', parent=current)
                    current.elem.append(item)
                else:
                    item = items[0]
                keys = keys[1:]
                current = item
            else:
                try:
                    item = current.attr[hop]
                except KeyError:
                    item = Miló(hop, parent=current, type='node')
                    current.attr[hop] = item
                current = item
        current.type = 'value'
        current.value = leafvalue
        # print('\n<<<<', path)
        # print("\n>>>>", "/".join([ c.name for c in current.trail([])]))
        # print('\n')
        return current
    # end def asym

    def asyd(doc, id_map, proleaf):
        keys, path, leafvalue, leaftype = proleaf
        hops = path.split('/')
        # print('------------------------------------\n')
        # print(f'THE PATH: {path}')
        first_hop = hops[0]
        current = doc
        parent = None
        last_act = None

        hops = hops[1:]
        for hop in hops:
            # print(f'\nTHE HOP: {hop}\nTHE MAP: {id_map}\nTHE DOC: {doc}')
            # if current is not None: print(f'\nTHE CUR: {current}\nTHE PAR: {parent}')
            if ('*' in hop):
                if type(current) is dict:
                    current = []
                    parent[last_act] = current
                key = keys[0]

                items = []
                for cur in current:
                    try:
                        if id(cur)==id_map[key]: items.append(cur)
                    except: 'pass'

                if not items:
                    item = {}
                    id_map[key] = id(item)
                    current.append(item)
                else:
                    item = items[0]
                keys = keys[1:]

            else:
                try:
                    item = current[hop]
                except KeyError:
                    item = {}
                    current[hop] = item

            parent = current
            last_act = hop
            current = item

        if type(current) is dict: parent[last_act] = leafvalue
        return doc
    # end def asyd

    def proleafs(config):
        ''' Miló.leafs(=[]) => Miló.proleafs '''
        root, Miló.leafs = Miló(''), []
        root.dedoc(config)

        def _star_(node):
            if (node.type=='item'): return node.name[0]
            else: return node.name

        def _numb_(node):
            if (node.type=='item'): return node.name.split('[')[1].split(']')[0]
            else: return ''

        def _nons_(name):
            if (':' in name): return name.split(':')[-1]
            else: return name

        def _type_(node):
            return {int: 'int', float: 'float', str: 'str', bool: 'bool'}[type(node.value)]

        report = []
        for leaf in Miló.leafs:
            tracerail = leaf.trail([])
            instance = [_numb_(n) for n in tracerail if (n.type=='item')]
            path = "/".join( [_nons_(_star_(n)) for n in tracerail] )
            # print(f"{instance}: {path} = <{_type_(leaf)}>{leaf.value}")
            report.append([instance, path, leaf.value, _type_(leaf)])
        return report
    # end def proleafs

    def profile(proleafs):
        length = []
        for proleaf in proleafs: length.append(len(proleaf[1].split('/')))
        print(f'proleafs number:{len(proleafs)} depth:{max(length)}')
    # end def profile

    def prodoc(proleafs):
        doc, id_map = {}, {}
        for proleaf in proleafs: Miló.asyd(doc, id_map, proleaf)
        return doc
    # end def prodoc
# end class Miló
