from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport memset, memcpy
NotMinimal = Exception()
NotEmbedded = Exception()
CompleteCover = Exception()
"""
Enumerate all covering spaces with bounded degree of a finite Cayley complex.

The algorithm used here is the one presented in "Computations with Finitely
Presented Groups" by Charles Sims, stripped of all of the irrelevant machinery
and viewed in the more natural context of covering spaces.

Conventions:

- A finite Cayley complex is a 2-complex with 1 vertex, G edges and
  finitely many 2-cells.  Each edge is directed and labeled with a
  positive integer.  The attaching maps of the 2-cells are represented
  by cyclically reduced words in the edge labels and their negations.
  A negative label indicates that the edge is traversed opposite to
  the edge's direction.  These cyclically reduced words are called
  relations.

- The vertices of a degree D finite cover of a Cayley complex are
  indexed as 1, ..., D. The base point is the vertex with index 1.

- The number R of edge labels is called the rank in the code. That
  refers to the rank of the free group that would be used in the group
  presentation associated with the Cayley complex.  Note that when a
  word is specified the rank must also be specified, since the word is
  being viewed as representing an element of a specific free group.

- The 1-skeleton of a cover of a finite Cayley complex is a labeled
  directed graph in which each vertex has G outgoing edges and G incoming
  edges, one for each label.  If the cover has degree D then it can
  be described with a DxG matrix in which the (i, j) entry is the index
  of the terminal vertex of the edge with initial vertex i and label j.
  This is called the matrix of outies.  A related DxG matrix, the matrix
  of innies, is the one for which the (i,j) entry is the index of the
  initial vertex of the edge with terminal vertex i and label j.  For
  efficiency we use and maintain both of these, even though they carry
  the same information. All entries of these matrices will be non-zero.

- While constructing covers we need to work with subgraphs of the
  1-skeletion.  A subgraph can be represented by a DxG matrix in which
  some of the entries are 0.  The (i,j) entry of the matrix of outties
  is 0 if and only if there is no edge with initial vertex i and
  label j in the subgraph.  Similarly, the (i,j) entry of the matrix
  of innies is 0 if and only if there is no edge with terminal vertex
  i and label j.  
"""


cdef class cWord():
    cdef int rank, start, length, size
    cdef char* buffer

    def __cinit__(self, int rank, byteseq):
        self.rank = rank
        self.start = 1
        self.length = len(byteseq)
        self.size = self.length + 2
        self.buffer = <char *>PyMem_Malloc(self.size)

    def __init__(self, int rank, byteseq):
        cdef int x  # GRRR C allows negative chars but Cython doesn't.
        for n in range(len(byteseq)):
            x = byteseq[n]
            x = x if x < 128 else x - 256  # GRRR No negative chars in Cython.
            if x == 0 or x > self.rank or x < -self.rank :
                raise ValueError(
                    'Invalid letter {0}; must be non-zero and in [-{1},{1}]'.format(
                        x, self.rank)
                    )
            self.buffer[self.start + n] = x

    def __dealloc__(self):
        PyMem_Free(self.buffer)

    def __len__(self):
        return self.length

    def __repr__(self):
        return 'cWord(%s)'%str(self)

    def __str__(self):
        word = []
        for i in range(self.start, self.start + self.length):
            word.append(self.buffer[i])
        return str(word)

    cdef repack(self):
        cdef char *old = self.buffer
        self.size = self.length + 2
        self.buffer = <char *>PyMem_Malloc(self.size)
        self.buffer[0] = 0
        for i in range(self.length):
            self.buffer[i] = old[self.start + i]
        self.start = 1
        PyMem_Free(old)
        
    cdef reduce(self):
        """
        This method reduces a word in a single pass though the word.
        """

        cdef int head = self.start, tail = self.start, length = self.length
        while True:
            tail += 1
            if tail >= length:
                break
            if self.buffer[head] + self.buffer[tail] == 0:
                self.length -= 2
                head -= 1
                continue
            head += 1
            self.buffer[head] = self.buffer[tail]

    cdef cyclically_reduce(self):
        """
        Cancels beginning and end letters only.  Assumes the word is reduced.
        """
        cdef int start = self.start
        cdef int end = self.start + self.length - 1
        while end > start:
            if self.buffer[start] + self.buffer[end] == 0:
                start += 1
                end -= 1
                self.length -= 2
            else:
                break
        self.start = start

cdef class ReducedWord(cWord):

    def __init__(self, int rank, byteseq):
        cWord.__init__(self, rank, byteseq)
        cWord.reduce(self)

    cdef _next_letter(self, int n):
        if n > 0:
            return -n
        if n > -self.rank:
            return 1 - n
        return 1

    cpdef _increment(self):
        """
        Private method!  Rewrites the buffer with the next word in the
        (length, lex) ordering, reallocating memory if necessary.
        [[This is harder that one would expect]].
        """
        cdef char next
        cdef char* buf = &self.buffer[self.start]
        cdef int len = self.length
        # Special case for the trivial word
        if len == 0:
            buf[0] = 1
            self.length = 1
            return
        # Easy case; just increase the last letter.
        if buf[len - 1] + self.rank != 0:
            next = self._next_letter(buf[len - 1])
            # But do not create a cancellation
            if len > 1 and (next + buf[len - 2] == 0):
                next = self._next_letter(next)
            if next != 1:
                buf[len - 1] = next
                return
        # Backtracking in the Cayley graph of the free group.
        n = len - 1
        # The word ends in a power of the next to biggest generator.
        if buf[n] == self.rank:
            while n > 0 and buf[n - 1] == self.rank:
                buf[n] = 1
                n -= 1
            buf[n] = -self.rank
        # The word ends in a power of the biggest generator.
        elif buf[n] + self.rank == 0:
            while buf[n] + self.rank == 0:
                n -= 1
            if n >= 0:
                buf[n] = self._next_letter(buf[n])
                if n > 0 and buf[n-1] + buf[n] == 0:
                    buf[n] = self._next_letter(buf[n])
                if buf[n] + 1 == 0:
                    for n in range(n + 1, self.length):
                        buf[n] = -1
                else:
                    for n in range(n + 1, self.length):
                        buf[n] = 1
        if n < 0:
            # We need to increase the length.
            # The first word will be a power of the first generator.
            if self.start < 1:
                self.repack()
            self.start -= 1
            self.length += 1
            buf = &self.buffer[self.start]
            for i in range(self.length):
                buf[i] = 1

    def __copy__(self):
        if self.length == 0:
            return ReducedWord(self.rank, [])
        return ReducedWord(self.rank,
            self.buffer[self.start:self.start + self.length])

cdef class ReducedWords:
    """
    Iterator for reduced words of a given rank with bounded length.
    """
    cdef ReducedWord current
    cdef int rank, max_length

    def __init__(self, int rank, int max_length=1, ReducedWord start=None):
        self.rank = rank
        self.max_length = max_length
        if start:
            self.current = start
        else:
            self.current = ReducedWord(rank, [])

    def __next__(self):
        if self.current.length > self.max_length:
            raise StopIteration
        result = self.current.__copy__()
        self.current._increment()
        return result

    def __iter__(self):
        return self

cdef class CyclicallyReducedWord(ReducedWord):

    def __init__(self, int rank, byteseq):
        ReducedWord.__init__(self, rank, byteseq)
        cWord.cyclically_reduce(self)            

cdef class CoveringSubgraph:
    cdef public int rank
    cdef public int degree
    cdef public int max_degree
    cdef public int num_edges
    cdef unsigned char* outies
    cdef unsigned char* innies
    cdef int height
    
    def __cinit__(self, rank, max_degree):
        self.height = 0
        self.degree = 1
        self.num_edges = 0
        self.rank = rank
        self.max_degree = max_degree
        cdef int size = self.rank*self.max_degree
        self.outies = <unsigned char *>PyMem_Malloc(size)
        memset(self.outies, 0, size)
        self.innies = <unsigned char *>PyMem_Malloc(self.rank**self.max_degree)
        memset(self.innies, 0, size)

    def __dealloc__(self):
        PyMem_Free(self.outies)
        PyMem_Free(self.innies)

    def __str__(self):
        cdef int t
        result = 'CoveringSubgraph with edges:\n'
        for f in range(self.degree):
            for n in range(self.rank):
                 t = self.outies[f*self.rank + n]
                 if t:
                     result += '%d--%d->%d\n'%(f + 1, n + 1, t)
        return result[:-1]

    def _data(self):
        print('out:', [n for n in self.outies[:self.rank*self.degree]])
        print('in:', [n for n in self.innies[:self.rank*self.degree]])
        
    def __copy__(self):
        return self.clone()

    def __key__(self):
        return self.outies[:self.rank*self.degree]

    def __hash__(self):
        return hash(self.__key__())

    def __eq__(self, other):
        if self.rank != other.rank:
            return False
        if self.degree != other.degree:
            return False
        for i in range(self.rank*self.degree):
            if self.outies[i] != other.outies[i]:
                return False
        return True

    def __lt__(self, other):
        return self.__key__() < other.__key__()

    def is_minimal(self):
        result = True
        for n in range(2, self.degree):
            perm, next, check = self.expand_perm(n)
            #print('perm:', perm)
            old_outies = [self.outies[i] for i in range(self.degree*self.rank)]
            #print('old:', [self.outies[i] for i in range(self.degree*self.rank)])
            new_outies = []
            for v in range(self.degree):
                for l in range(self.rank):
                    if perm[v] == 0:
                        new_outies.append(0)
                    else:
                        new_outies.append(perm[self.outies[(perm[v] - 1)*self.rank + l] - 1])
            #print('new', [new_outies[i] for i in range(self.degree*self.rank)])
            if new_outies < old_outies:
                result = False
                break
        return result

        # for n in range(1, self.degree):
        #     try:
        #         self.expand_perm(n+1, check=True)
        #     except:
        #         return False
        # return True

    def expand_perm(self, int vertex, perm=None, next=None, check=False):
        if perm is None:
            # The new basepoint will be named 1
            perm = [0]*self.degree
            perm[vertex - 1] = 1
            next = 2
            if check:
                check=1
        if next > self.degree:
            #print('Out of indices')
            return perm, next, check
        # Examine all of the outgoing edges at a given vertex.
        # Assign consecutive indices, starting with next, to the
        # terminal vertices those edges, skipping any of those
        # endpoints which have already been assigned an index.
        # If a non-existent edge is found, stop. Otherwise,
        # recursively visit each of those vertices in order.
        #print('starting with', perm, next, check)
        terminals = []
        for l in range(self.rank):
            out = self.outies[(vertex - 1)*self.rank + l]
            if not out:
                return perm, next, check
            #print('Checking edge %d--%d-->%d'%(vertex, l+1, out))
            if not perm[out - 1]:
                #print('The new index of %d is %d'%(out, next))
                perm[out - 1] = next
                if check:
                    #print('Checking with check =', check)
                    old_outies = [self.outies[i] for i in range(self.degree*self.rank)]
                    #print('old:', [self.outies[i] for i in range(self.degree*self.rank)])
                    new_outies = []
                    for v in range(self.degree):
                        for l in range(self.rank):
                            if perm[v] == 0:
                                new_outies.append(0)
                            else:
                                new_outies.append(perm[self.outies[(perm[v] - 1)*self.rank + l] - 1])
                    #print('new', [new_outies[i] for i in range(self.degree*self.rank)])
                    if new_outies < old_outies:
                        raise NotMinimal
                    # The outie matrix is minimal up to the vertex with index check.
                    # See if adding this new vertex will reduce it.
                    # for l in range(self.rank):
                    #     old = self.outies[(check - 1)*self.rank + l]
                    #     new = self.outies[(perm[check - 1] - 1)*self.rank + l]
                    #     print('old:', old, 'new:', new)
                    #     if old < new:
                    #         break
                    #     if new < old:
                    #         print('Not minimal')
                    #         raise NotMinimal
                    # check += 1
                next += 1
                terminals.append(out)
        for vertex in terminals:
            #print('Recursing to %s'%vertex)
            perm, next, check = self.expand_perm(vertex, perm, next, check)
        return perm, next, check

    cpdef is_complete(self):
        return self.num_edges == self.rank*self.degree

    cdef clone(self):
        cdef int size = self.rank*self.max_degree
        result = CoveringSubgraph(self.rank, self.max_degree)
        result.degree = self.degree
        result.num_edges = self.num_edges
        memcpy(result.outies, self.outies, size)
        memcpy(result.innies, self.innies, size)
        return result
        
    cdef check_label(self, n):
        assert 0 < n <= self.rank or -self.rank <= n < 0, \
          'Labels must lie in [-{0}, -1] or [1, {0}].'.format(self.rank)

    cdef check_vertex(self, n):
        assert 0 < n <= self.max_degree, 'vertices must lie in [1, %d]'%self.max_degree

    cpdef add_edge(self, int letter, int from_vertex, int to_vertex):
        """
        Add an edge.
        """
        cdef int out_index, in_index, label = letter
        self.check_vertex(from_vertex)
        self.check_vertex(to_vertex)
        if letter < 0:
            label, from_vertex, to_vertex = -letter, to_vertex, from_vertex
        assert from_vertex <= self.max_degree and to_vertex <= self.max_degree, \
            'Vertex index is out of range.'
        if from_vertex > self.degree or to_vertex > self.degree:
            assert to_vertex <= self.degree + 1 and from_vertex <= self.degree + 1 
            self.degree += 1
        out_index = (from_vertex - 1)*self.rank + label - 1
        in_index = (to_vertex - 1)*self.rank + label - 1
        if self.outies[out_index] != 0 or self.innies[in_index] != 0:
            print('Error adding edge %d--(%d)->%d'%(
                from_vertex, letter, to_vertex))
            self._data()
            print(self)
        assert self.outies[out_index] == 0, str(self)
        assert self.innies[in_index] == 0, str(self)
        self.outies[out_index] = to_vertex
        self.innies[in_index] = from_vertex
        self.num_edges += 1

    cdef act_by(self, int letter, int vertex):
        self.check_vertex(vertex)
        self.check_label(letter)
        if letter > 0:
            return self.outies[(vertex - 1)*self.rank + letter - 1]
        elif letter < 0:
            return self.innies[(vertex - 1)*self.rank - letter - 1]

    cpdef lift(self, cWord word, int vertex):
        cdef int initial = vertex
        cdef int length = 0
        cdef int saved = vertex
        assert word.rank == self.rank
        for n in range(word.length):
            vertex = self.act_by(word.buffer[word.start + n], vertex)
            if vertex == 0:
                break
            saved = vertex
            length += 1
        return saved, length

    cpdef lift_inverse(self, cWord word, int vertex):
        cdef int length = 0
        cdef int saved = vertex
        assert word.rank == self.rank
        cdef int end = word.start + word.length - 1
        for n in range(word.length):
            vertex = self.act_by(-word.buffer[end - n], vertex)
            if vertex == 0:
                break
            saved = vertex
            length += 1
        return saved, length

    cdef first_empty_slot(self, int basepoint=1):
        cdef int v, l
        for n in range(self.height, self.rank*self.degree):
            # can set the height here.
            if self.outies[n] == 0:
                v = n // self.rank
                l = n % self.rank
                return v + 1, l + 1
            if self.innies[n] == 0:
                v = n // self.rank
                l = n % self.rank
                return v + 1, -(l + 1)

cdef class SimsTree:
    """
    A tree of CoveringSubgraphs constructed by the algorithm.  Each
    CoveringSubgraph in the tree is constructed by adding edges to
    its parent in such a way that every relation that can be lifted
    lifts to a loop.  (It is allowed for a relation to fail to lift
    because an edge is missing from the subgraph.)
    """
    cdef public int rank
    cdef public int max_degree
    cdef public SimsNode root
    cdef SimsNode next
    cdef char done
    # Workspaces used by SimsNodes when checking minimality
    cdef unsigned char *new
    cdef unsigned char *wen

    def __cinit__(self):
        self.new = <unsigned char*>PyMem_Malloc(self.max_degree + 1)
        self.wen = <unsigned char*>PyMem_Malloc(self.max_degree + 1)

    def __dealloc__(self):
        PyMem_Free(self.new)
        PyMem_Free(self.wen)

    def __init__(self, int rank, int max_degree):
        self.rank = rank
        self.max_degree = max_degree
        subgraph=CoveringSubgraph(rank=rank, max_degree=max_degree)
        self.root = SimsNode(subgraph, tree=self)
        self.bloom()

    def __iter__(self):
        class TreeIterator:
            """
            Iterate through all leaf nodes in the tree with complete subgraphs.
            """

            def __init__(self, SimsTree tree):
                self.next = tree.root
                self.path = [0]
                while self.next.children:
                    self.path.append(0)
                    self.next = self.next.children[0]
                self.done = False

            def __next__(self):
                cdef SimsNode result
                if self.done:
                    raise StopIteration
                result = self.next
                try:
                    self.next = self.next.parent.children[self.path[-1] + 1]
                    self.path[-1] += 1
                except AttributeError:
                    # The root is the only node, so it is a leaf.
                    self.done = True
                    return result
                except IndexError:
                    while self.next.parent:
                        self.next = self.next.parent
                        index = self.path.pop() + 1
                        if not self.path:
                            self.done = True
                        if index < len(self.next.children):
                            self.path.append(index)
                            self.next = self.next.children[index]
                            break
                    if self.path == [0]:
                        self.done = True
                while self.next.children:
                    self.path.append(0)
                    self.next = self.next.children[0]
                return result

        return TreeIterator(self)

    def as_list(self):
        return [n.subgraph for n in self if n.subgraph.is_complete()]

    cdef add_child(self, child):
        child.parent.children.append(child)

    cdef bloom(self):
        cdef SimsNode tip
        cdef int count = 0
        while True:
            count = 0
            for tip in self:
                count += tip.sprout()
            if count == 0:
                break

cdef class SimsNode:
    """
    A node in a SimsTree, containing a based partial covering.
    """
    cdef SimsTree tree
    cdef public SimsNode parent
    cdef public list children
    cdef public CoveringSubgraph subgraph

    def __init__(self, subgraph, tree=None, parent=None):
        self.subgraph = subgraph
        self.tree = tree
        self.parent = parent
        self.children = []

    cdef sprout(self):
        """
        Find the first empty edge slot in this based partial covering.  For each
        possible way to add an edge in that slot, create a child node containing
        the subgraph obtained by adding that edge.  Return the number of
        children added.
        """
        cdef int v, l, count
        cdef CoveringSubgraph new_subgraph, g = self.subgraph
        cdef SimsNode parent, node, new_leaf
        assert not self.children, 'Can only sprout from a bud.'
        try:
            v, l = g.first_empty_slot()
        except TypeError:
            return 0
        # Add edges with from this slot to all possible target slots.
        targets = []
        if l > 0:
            for n in range(g.degree):
                t = g.innies[n*g.rank + l - 1]
                if t == 0:
                    targets.append((l, v, n+1))
        else:
            for n in range(g.degree):
                t = g.outies[n*g.rank - l - 1]
                if t == 0:
                    targets.append((l, v, n+1))
        # Also add an edge to a new vertex if allowed.
        if g.degree < g.max_degree:
            targets.append((l, v, g.degree + 1))
        count = 0
        for target in targets:
            new_subgraph = g.clone()
            new_subgraph.add_edge(*target)
            new_leaf = SimsNode(new_subgraph, tree=self.tree, parent=self)
            if new_leaf.keep():
                self.tree.add_child(new_leaf)
                count += 1
        return count

    cdef keep(self):
        """
        Return False if the subgraph can provably not be extended to a cover
        which is minimal in its conjugacy class, True otherwise.

        The ordering of based coverings is given as follows.  Given a covering
        with rank R and degree D, consider all pairs (N, L) where N is a vertex
        index in [1, D] and L is a signed label in [-R, -1] or [1, R].  Order
        the signed labels as 1, -1, 2, -2, ..., R, -R.  Use that to lex order
        the 2*D*R pairs (N, L).  For each pair (N,L) assign an edge E(N, L) and
        a number s(N, L) as follows:

            * if L > 0, E(N, L) is the edge with initial vertex N and
              label L and s(N, L) is index of its terminal vertex.

            * if L < 0, E(N, L) is the edge with terminal vertex N and
              label -L and s(N, L) is the index of its initial vertex.

        The list [s(N, L) for all (N, L)] is the complexity of the covering;
        complexities are ordered lexicographically.

        Any conjugate of the subgroup corresponding to a covering graph can be
        obtained by changing the basepoint.  A choice of basepoint determines an
        indexing of the vertices where the index of a vertex v is the index of
        the first pair (N, L) such that E(N, L) has v as its terminal (initial)
        vertex if L > 0 (L < 0).  We only enumerate based coverings for which
        the basepoint is chosen to minimize complexity.  The subgroups
        corresponding to these coverings will then by unique up to conjugacy.

        Even when working with a proper subgraph of a covering graph (containing
        the basepoint) it may be possible to deduce that the subgraph cannot be
        extended to a minimal covering.  In such a case the subgraph should not
        be added to the Sims tree.  If this test is done at each stage of the
        construction of the tree, the complete graphs in the final tree will
        automatically be minimal.

        This method iterates through all vertices of the subgraph, constructing
        as much as possible of the vertex ordering determined by taking that
        vertex as a basepoint.  It returns False as soon as it encounters an
        edge which would result in a higher complexity. If no such edge is found
        for any choice of basepoint it returns True.
        """
        cdef unsigned char *old_to_new = self.tree.new
        cdef unsigned char *new_to_old = self.tree.wen
        cdef int basepoint, next_index, old_index, new_index, next_basepoint
        cdef int degree = self.subgraph.degree
        cdef int rank = self.subgraph.rank
        cdef int a, b, c
        cdef unsigned char *outies = self.subgraph.outies
        cdef unsigned char *innies = self.subgraph.innies
        for basepoint in range(2, degree + 1):
            memset(old_to_new, 0, degree + 1)
            memset(new_to_old, 0, degree + 1)
            next_basepoint = 0
            # Attempt to find the indexing determined by this basepoint.
            next_index = 1
            old_to_new[basepoint] = 1
            new_to_old[1] = basepoint
            for new_index in range(1, degree + 1):
                old_index = new_to_old[new_index]
                assert old_index != 0
                for n in range(2*rank):
                    sign = n % 2
                    l = n // 2
                    bail = False
                    # Try to find an incident edge with label l + 1 or -(l + 1).
                    if sign == 0: # positive label
                        a = outies[(new_index - 1)*rank + l] # outgoing to old a
                        b = outies[(old_index - 1)*rank + l] # outgoing to old b
                    else: # negative label
                        a = innies[(new_index - 1)*rank + l] # incoming from old a
                        b = innies[(old_index - 1)*rank + l] # incoming from old b
                    if a == 0 or b == 0:
                        # Not enough edges to decide.
                        next_basepoint = True
                        break
                    #Compare the old and new indices of the other end of the edge
                    if old_to_new[b] == 0:
                        # Update the mappings between the old and new indices.
                        next_index += 1
                        old_to_new[b] = next_index
                        new_to_old[next_index] = b
                    c = old_to_new[b]
                    if c < a:
                        # The new basepoint is better - discard this graph.
                        return False
                    if c > a:
                        # The old basepoint is better - try the next one.
                        next_basepoint = True
                        break
                if next_basepoint:
                    break
        return True
