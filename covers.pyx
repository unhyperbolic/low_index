from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport memset, memcpy
NotMinimal = Exception()

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
            for l in range(self.rank):
                 t = self.outies[f*self.rank + l]
                 if t:
                     result += '%d--%d->%d\n'%(f + 1, l + 1, t)
        return result

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
            if new_outies == old_outies:
                print('has Automorphism 1 -> %d'%n)
        #print(result)
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
                    print('old:', [self.outies[i] for i in range(self.degree*self.rank)])
                    new_outies = []
                    for v in range(self.degree):
                        for l in range(self.rank):
                            if perm[v] == 0:
                                new_outies.append(0)
                            else:
                                new_outies.append(perm[self.outies[(perm[v] - 1)*self.rank + l] - 1])
                    print('new', [new_outies[i] for i in range(self.degree*self.rank)])
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
    cdef SimsTree tree
    cdef public SimsNode parent
    cdef public list children
    cdef public CoveringSubgraph subgraph

    def __init__(self, subgraph, tree=None, parent=None):
        self.subgraph = subgraph
        self.tree = tree
        self.parent = parent
        self.children = []

    def sprout(self):
        cdef int f, t, l
        cdef CoveringSubgraph g = self.subgraph
        cdef CoveringSubgraph new_subgraph
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
            new_subgraph = g.clone()
            new_subgraph.add_edge(l+1, f + 1, target)
            new_leaf = SimsNode(new_subgraph, tree=self.tree, parent=self)
            new_leaves.append(new_leaf)
        self.children += new_leaves
        return len(new_leaves)

    cpdef keep(self):
        """
        Returns False if the subgraph can provably not be extended to
        a cover which is minimal in its conjugacy class.

        Covering are ordered by comparing their flattened outie matrices
        in lexicographical order.  A priori the outie matrix of a covering
        graph is determined by choosing an index for each vertex.  However
        for the subgraphs that we construct the outie matrix is actually
        determined just by the choice of a basepoint.  This is because the
        graphs are constructed to have minimal outie matrices given the
        choice of basepoint.  More specifically, the basepoint always has
        index n and the remaining vertices are ordered according to which
        vertex is the first one to become the terminal vertex of an edge.
        So the second vertex is the terminal vertex of the first (ordered
        by label) edge attached to vertex 1 which is not a loop.  And so
        on.

        Since any conjugate of the subgroup corresponding to a covering
        graph can be obtained by changing the basepoint, and since every
        choice of basepoint determines an ordering of the vertices, we
        can decide which choice of basepoint gives the minimal element
        of the conjugacy class.  Even when working with a proper subgraph
        of a covering graph (containing the basepoint) it may be possible
        to deduce that the subgraph cannot be extended to a minimal
        covering graph.  In such a case the subgraph should not be added
        to the Sims tree.  If this test is done at each stage of the
        construction of the tree, the complete graphs in the final tree
        will automatically be minimal.

        The idea of this method is to iterate through all vertices of
        the subgraph and to build as much of the vertex ordering as
        possible, returning False as soon as the outie matrix given by
        the new ordering would have a smaller outie matrix.  In the
        code, the array new (partially) represents the permutation
        mapping the original vertex indices to the new indices, and
        the array wen represents its inverse.  The temporary memory
        used for these belongs to the tree.
        """
        cdef unsigned char *new = self.tree.new
        cdef unsigned char *wen = self.tree.wen
        cdef int v, l, bp, last_index, a, b, c, bail
        cdef int degree = self.subgraph.degree
        cdef int rank = self.subgraph.rank
        cdef unsigned char *outies = self.subgraph.outies
        #print([outies[i] for i in range(rank*degree)])
        #print(self.subgraph)
        memset(new, 0, degree + 1)
        for bp in range(2, degree + 1):
            # Attempt to find the permutation for this basepoint
            # An edge V--L->W will appear as new[V]--L->new[W]
            # after moving the basepoint.
            last_index = 1
            new[bp] = 1
            wen[1] = bp
            print('moving basepoint to %d'%bp)
            print('outies', [outies[i] for i in range(rank*degree)])
            for vertex in range(2, degree + 1):
                bail = False
                for l in range(rank):
                    print('vertex =', vertex, 'wen[vertex] =', wen[vertex])
                    a = outies[(vertex - 1)*rank + l]
                    b = outies[(wen[vertex] - 1)*rank + l]
                    print('a =', a, 'b =', b)
                    if a == 0 or b == 0:
                        bail = True
                        break
                    if new[b] == 0:
                        last_index += 1
                        new[b] = last_index
                        wen[last_index] = b
                        print([new[i] for i in range(1, degree+ 1)])
                    c = new[b]
                    print('a =', a, 'b =', b, 'c =', c)
                    if c < a:
                        print('final:', [new[i] for i in range(1, degree+1)])
                        return False
                    if c > a:
                        print('c > a')
                        bail = True
                        break
                if bail:
                    print('bailed')
                    for n in range(1, last_index + 1):
                        new[wen[n]] = 0
                    continue
        print('final:',[new[i] for i in range(degree)])
        return True
