from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport memset, memcpy

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

- The number G of edges is called the rank in the code. That refers to
  the rank of the free group that would be used in the group
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
    cdef int rank, start, max, length
    cdef char* buffer

    def __cinit__(self, int rank, byteseq):
        self.rank = rank
        self.start = 0
        self.max = self.length = len(byteseq)
        self.buffer = <char *>PyMem_Malloc(self.max)

    def __init__(self, int rank, byteseq):
        for n, x in enumerate(byteseq):
            if x == 0 or x < -self.rank or x > self.rank:
                raise ValueError(
                    'Letters are non-zero and in [-{},{}]'.format(self.rank)
                    )
            self.buffer[n] = x

    def __dealloc__(self):
        PyMem_Free(self.buffer)

    def __len__(self):
        if self.length > 0:
            return self.length
        return 0

    def __repr__(self):
        return 'cWord(%s)'%str(self)

    def __str__(self):
        word = []
        for i in range(self.start, self.start + self.length):
            word.append(self.buffer[i])
        return str(word)

    cdef repack(self):
        cdef char *old = self.buffer
        self.max = self.length
        self.buffer = <char *>PyMem_Malloc(self.max)
        for i in range(self.length):
            self.buffer[i] = old[self.start + i]
        self.start = 0
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

cdef class CyclicallyReducedWord(ReducedWord):

    def __init__(self, int rank, byteseq):
        ReducedWord.__init__(self, rank, byteseq)
        cWord.cyclically_reduce(self)

cdef class CoveringSubgraph:
    cdef public int rank
    cdef public int degree
    cdef public int max_degree
    cdef public int num_edges
    cdef char* outies
    cdef char* innies
    cdef int height
    
    def __cinit__(self, rank, max_degree):
        self.height = 0
        self.degree = 1
        self.num_edges = 0
        self.rank = rank
        self.max_degree = max_degree
        cdef int size = self.rank*self.max_degree
        self.outies = <char *>PyMem_Malloc(size)
        memset(self.outies, 0, size)
        self.innies = <char *>PyMem_Malloc(self.rank**self.max_degree)
        memset(self.innies, 0, size)

    def __dealloc__(self):
        PyMem_Free(self.outies)
        PyMem_Free(self.innies)

    def __str__(self):
        cdef int t
        result = 'CoveringSubgraph with edges:\n'
        for f in range(self.degree):
            for l in range(self.rank):
                 t = self.outies[f*self.rank + l]
                 if t:
                     result += '%d--%d->%d\n'%(f + 1, l + 1, t)
        return result

    def __copy__(self):
        return self.clone()

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

    cpdef add_edge(self, int label, int from_vertex, int to_vertex):
        """
        Add an edge with a **positive** label.
        """
        cdef int index
        assert 0 < label <= self.rank, \
          'The label must be positive when adding an edge.'
        self.check_vertex(from_vertex)
        self.check_vertex(to_vertex)
        assert from_vertex <= self.degree and to_vertex <= self.max_degree, \
            'Vertex index is out of range.'
        if to_vertex > self.degree:
            self.degree = to_vertex
        index = (from_vertex - 1)*self.rank + label - 1
        self.outies[index] = to_vertex
        index = (to_vertex - 1)*self.rank + label - 1
        self.innies[index] = from_vertex
        self.num_edges += 1

    cdef act_by(self, int letter, int vertex):
        self.check_vertex(vertex)
        self.check_label(letter)
        if letter > 0:
            return self.outies[(vertex - 1)*self.rank + letter - 1]
        elif letter < 0:
            return self.innies[(vertex - 1)*self.rank - letter - 1]

    cpdef lift(self, cWord word, int vertex):
        assert word.rank == self.rank
        for n in range(word.length):
            vertex = self.act_by(word.buffer[word.start + n], vertex)
            if vertex == 0:
                break
        return vertex, n + 1

    cpdef lift_inverse(self, cWord word, int vertex):
        assert word.rank == self.rank
        cdef int end = word.start + word.length - 1
        for n in range(word.length):
            vertex = self.act_by(-word.buffer[end - n], vertex)
            if vertex == 0:
                break
        return vertex, n + 1

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

    def __init__(self, int rank, int max_degree):
        self.rank = rank
        self.max_degree = max_degree
        subgraph=CoveringSubgraph(rank=rank, max_degree=max_degree)
        self.root = SimsNode(subgraph)

    def __iter__(self):
        class TreeIterator:
            """
            Iterate through all leaf nodes in the tree.
            """

            def __init__(self, SimsTree tree):
                self.next = tree.root
                self.path = [0]
                while self.next.children:
                    self.path.append(0)
                    self.next = self.next.children[0]
                self.done = False

            def __next__(self):
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

    cdef add_child(self, child):
        child.parent.children.append(child)

    def bloom(self):
        while True:
            count = 0
            for tip in self:
                count += tip.sprout()
            if count == 0:
                break

cdef class SimsNode:
    """
    A node in a SimsTree.
    """
    cdef public SimsNode parent
    cdef public list children
    cdef public CoveringSubgraph subgraph

    def __init__(self, subgraph, parent=None):
        self.parent = parent
        self.subgraph = subgraph
        self.children = []

    def sprout(self):
        cdef int f, t, l
        cdef CoveringSubgraph g = self.subgraph
        cdef CoveringSubgraph new
        assert not self.children, 'Can only burst a leaf.'
        if g.is_complete():
            return 0
        for n in range(g.height, g.rank*g.degree):
            # can set the height here.
            if g.outies[n] == 0:
                break
        f = n // g.rank
        l = n % g.rank
        # Add edges with this from vertex and label to all possible targets.
        targets = []
        for n in range(g.degree):
            t = g.innies[n*g.rank + l]
            if t == 0:
                targets.append(n+1)
        # Also add an edge to a new vertex if allowed.
        if g.degree < g.max_degree:
            targets.append(g.degree + 1)
        new_leaves = []
        for target in targets:
            new = g.clone()
            new.add_edge(l+1, f + 1, target)
            new_leaves.append(SimsNode(new, parent=self))
        self.children += new_leaves
        return len(new_leaves)
