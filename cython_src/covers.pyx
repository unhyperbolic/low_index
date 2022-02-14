"""
Enumerate all based covering spaces with bounded degree of a finite Cayley
complex such that the basepoint has minimal complexity.

The algorithm used here is the one presented in "Computations with Finitely
Presented Groups" by Charles Sims, stripped of all of the irrelevant machinery
and viewed in the more natural context of covering spaces.

Conventions:

- A finite Cayley complex is a 2-complex with 1 vertex, G edges and finitely
  many 2-cells.  Each edge is directed and labeled with a positive integer.  The
  attaching maps of the 2-cells are represented by cyclically reduced words in
  the edge labels and their negations.  A negative label indicates that the edge
  is traversed opposite to the edge's direction.  These cyclically reduced words
  are called relations.

- The vertices of a degree D finite cover of a Cayley complex are indexed as
  1, ..., D. The base point is the vertex with index 1.

- The number R of edge labels is called the rank in the code. That refers to the
  rank of the free group that would be used in the group presentation associated
  with the Cayley complex.  Note that when a word is specified the rank must
  also be specified, since the word is being viewed as representing an element
  of a specific free group.

- The 1-skeleton of a cover of a finite Cayley complex is a labeled directed
  graph in which each vertex has G outgoing edges and G incoming edges, one for
  each label.  If the cover has degree D then it can be described with a DxG
  matrix in which the (i, j) entry is the index of the terminal vertex of the
  edge with initial vertex i and label j.  This is the outgoing matrix.
  A related DxG matrix, the incoming matrix, is the one for which the (i,j)
  entry is the index of the initial vertex of the edge with terminal vertex i
  and label j.  For efficiency we use and maintain both of these, even though
  they carry the same information. All entries of these matrices will be
  non-zero in a complete covering graph.

- While constructing covers we need to work with subgraphs of the 1-skeletion.
  A subgraph can be represented by a DxG matrix in which some of the entries are
  0.  The (i,j) entry of the matrix of outties is 0 if and only if there is no
  edge with initial vertex i and label j in the subgraph.  Similarly, the (i,j)
  entry of the matrix of incoming is 0 if and only if there is no edge with
  terminal vertex i and label j.
"""

cdef class CoveringSubgraph:
    cdef public int rank
    cdef public int degree
    cdef public int max_degree
    cdef int num_edges
    cdef int num_relators
    cdef unsigned char* outgoing
    cdef unsigned char* incoming
    cdef unsigned char* lift_indices
    cdef unsigned char* lift_vertices

    def __cinit__(self, int rank, int max_degree, int num_relators=0):
        self.degree = 1
        self.num_edges = 0
        self.rank = rank
        self.max_degree = max_degree
        self.num_relators = num_relators
        cdef int size = self.rank*self.max_degree
        self.outgoing = <unsigned char *>PyMem_Malloc(size)
        memset(self.outgoing, 0, size)
        self.incoming = <unsigned char *>PyMem_Malloc(size)
        memset(self.incoming, 0, size)
        if num_relators > 0:
            # maintain state for each relator at each vertex
            size = num_relators*max_degree
            self.lift_indices = <unsigned char *>PyMem_Malloc(size)
            memset(self.lift_indices, 0, size)
            self.lift_vertices = <unsigned char *>PyMem_Malloc(size)
            memset(self.lift_vertices, 0, size)

    def __dealloc__(self):
        PyMem_Free(self.outgoing)
        PyMem_Free(self.incoming)
        if self.num_relators:
            PyMem_Free(self.lift_indices)
            PyMem_Free(self.lift_vertices)

    def __str__(self):
        cdef int t
        result = 'Covering graph with edges:\n'
        for f in range(self.degree):
            for n in range(self.rank):
                 t = self.outgoing[f*self.rank + n]
                 if t:
                     result += '%d--%d->%d\n'%(f + 1, n + 1, t)
        return result[:-1]

    def _data(self):
        print('out:', [n for n in self.outgoing[:self.rank*self.degree]])
        print('in:', [n for n in self.incoming[:self.rank*self.degree]])

    def __copy__(self):
        return self.clone()

    def __key__(self):
        return self.outgoing[:self.rank*self.degree]

    def __hash__(self):
        return hash(self.__key__())

    def __eq__(self, other):
        if self.rank != other.rank:
            return False
        if self.degree != other.degree:
            return False
        for i in range(self.rank*self.degree):
            if self.outgoing[i] != other.outgoing[i]:
                return False
        return True

    def __lt__(self, other):
        return self.__key__() < other.__key__()

    cpdef is_complete(self):
        return self.num_edges == self.rank*self.degree

    cdef clone(self):
        cdef int size = self.rank*self.max_degree
        result = CoveringSubgraph(self.rank, self.max_degree,
                                      self.num_relators)
        result.degree = self.degree
        result.num_edges = self.num_edges
        result.num_relators = self.num_relators
        memcpy(result.outgoing, self.outgoing, size)
        memcpy(result.incoming, self.incoming, size)
        if self.num_relators > 0:
            size = self.num_relators
            memcpy(result.lift_indices, self.lift_indices, size)
            memcpy(result.lift_vertices, self.lift_vertices, size)
        return result

    cdef add_edge(self, int letter, int from_vertex, int to_vertex):
        """
        Add an edge.
        """
        cdef int out_index, in_index, label = letter
        if letter < 0:
            label, from_vertex, to_vertex = -letter, to_vertex, from_vertex
        if from_vertex > self.degree or to_vertex > self.degree:
            self.degree += 1
        out_index = (from_vertex - 1)*self.rank + label - 1
        in_index = (to_vertex - 1)*self.rank + label - 1
        self.outgoing[out_index] = to_vertex
        self.incoming[in_index] = from_vertex
        self.num_edges += 1

    cdef act_by(self, int letter, int vertex):
        if letter > 0:
            return self.outgoing[(vertex - 1)*self.rank + letter - 1]
        elif letter < 0:
            return self.incoming[(vertex - 1)*self.rank - letter - 1]

    cpdef lift(self, ReducedWord word, int vertex):
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

    cpdef lift_inverse(self, ReducedWord word, int vertex):
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
        cdef div_t qr
        for n in range(self.rank*self.degree):
            if self.outgoing[n] == 0:
                qr = div(n, self.rank)
                v = qr.quot
                l = qr.rem
                return v + 1, l + 1
            if self.incoming[n] == 0:
                qr = div(n, self.rank)
                v = qr.quot
                l = qr.rem
                return v + 1, -(l + 1)

    cdef sprout(self, SimsTree tree):
        """
        Find the first empty edge slot in this based partial covering.  For each
        possible way to add an edge in that slot, create a new node containing
        the subgraph obtained by adding that edge.  Return the list of new nodes.
        """
        cdef int n, v, l, i, rank=self.rank
        cdef CoveringSubgraph new_subgraph
        cdef list children = []
        try:
            v, l = self.first_empty_slot()
        except TypeError:
            return []
        # Add edges with from this slot to all possible target slots.
        targets = []
        if l > 0:
            i = 0
            for n in range(self.degree):
                t = self.incoming[i + l - 1]
                i += rank
                if t == 0:
                    targets.append((l, v, n+1))
        else:
            i = 0
            for n in range(self.degree):
                t = self.outgoing[i - l - 1]
                i += rank
                if t == 0:
                    targets.append((l, v, n+1))
        # Also add an edge to a new vertex if allowed.
        if self.degree < self.max_degree:
            targets.append((l, v, self.degree + 1))
        for l, v, n in targets:
            new_subgraph = self.clone()
            new_subgraph.add_edge(l, v, n)
            if (self.relators_may_lift(new_subgraph, tree)
                    and new_subgraph.keep(tree)):
                children.append(new_subgraph)
        return children

    cdef relators_may_lift(self, CoveringSubgraph child, SimsTree tree):
        """
        Check that all relators either lift to a loop or run into a missing edge
        at every vertex of a child subgraph.  Use the saved state of this
        subgraph as a starting point for checking the child.
        """
    
        cdef CyclicallyReducedWord w
        cdef char l, index, vertex, start, save, length
        cdef int n = 0, v, i = 0, j, rank=child.rank, max_degree=child.max_degree
        for w in tree.relators:
            length = w.length
            for v in range(child.degree):
                # Check whether relator n lifts to vertex v + 1.
                j = n*max_degree + v
                index = self.lift_indices[j]
                if index >= length:
                    # We already know the relator lifts to this vertex.
                    continue
                start = self.lift_vertices[j]
                if start == 0:
                    # The state is uninitialized.
                    start = v + 1
                vertex = start
                for i in range(index, length):
                    l = w.buffer[w.start + i]
                    save = vertex
                    if l > 0:
                        vertex = child.outgoing[rank*(vertex - 1) + l - 1]
                    else:
                        vertex = child.incoming[rank*(vertex - 1) - l - 1]
                    if vertex == 0:
                        break
                if vertex == 0:
                    # We hit a missing edge - save the state and go on.
                    child.lift_vertices[j] = save
                    child.lift_indices[j] = i
                    break 
                if i == length - 1:
                    # The entire relator lifted.  Is it a loop?
                    if vertex == v + 1:
                        # Yes.  Record that it lifts to a loop.
                        child.lift_vertices[j] = vertex
                        child.lift_indices[j] = length
                    else:
                        # No.  Discard this child.
                        return False
            n += 1
        return True

    cdef keep(self, SimsTree tree):
        """
        Return False if the subgraph can provably not be extended to a cover
        which is minimal in its conjugacy class, True otherwise.

        The ordering of based coverings is given as follows.  Given a covering
        with rank R and degree D, consider all pairs (N, L) where N is a vertex
        index in [1, D] and L is a signed label in [-R, -1] or [1, R].  Order
        the signed labels as 1, -1, 2, -2, ..., R, -R.  Use that to lex order
        the 2*D*R pairs (N, L).  For each pair (N, L) assign an edge E(N, L) and
        a number s(N, L) as follows:

            * if L > 0, E(N, L) is the edge with initial vertex N and
              label L and s(N, L) is index of its terminal vertex.

            * if L < 0, E(N, L) is the edge with terminal vertex N and
              label -L and s(N, L) is the index of its initial vertex.

        The list [s(N, L) for all (N, L)] is the complexity of the covering;
        complexities are ordered lexicographically.

        Any conjugate of the subgroup corresponding to a covering graph can be
        obtained by changing the basepoint.  A choice of basepoint determines an
        indexing of the vertices where the index of a vertex v is the next
        available index at the moment when the first E(N, L) having v as its
        terminal (initial) vertex if L > 0 (L < 0) is added.  We only enumerate
        based coverings for which the basepoint is chosen to minimize
        complexity.  The subgroups corresponding to these coverings will then by
        unique up to conjugacy.

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
        cdef unsigned char *old_to_new = tree.old_to_new
        cdef unsigned char *new_to_old = tree.new_to_old
        cdef int basepoint, next_basepoint, old_index, new_index, next_index
        cdef int degree = self.degree, rank = self.rank
        cdef int a, b, c
        cdef unsigned char *outgoing = self.outgoing
        cdef unsigned char *incoming = self.incoming
        for basepoint in range(2, degree + 1):
            memset(old_to_new, 0, degree + 1)
            # It is not necessary to clear new_to_old
            #memset(new_to_old, 0, degree + 1)
            next_basepoint = 0
            # Attempt to find the indexing determined by this basepoint.
            next_index = 1
            old_to_new[basepoint] = 1
            new_to_old[1] = basepoint
            for new_index in range(1, degree + 1):
                old_index = new_to_old[new_index]
                for n in range(2*rank):
                    sign = n & 0x1
                    l = n >> 1
                    # Try to find an incident edge with label l + 1 or -(l + 1).
                    if sign == 0: # positive label
                        a = outgoing[(new_index - 1)*rank + l] # to old a
                        b = outgoing[(old_index - 1)*rank + l] # to old b
                    else: # negative label
                        a = incoming[(new_index - 1)*rank + l] # from old a
                        b = incoming[(old_index - 1)*rank + l] # from old b
                    if a == 0 or b == 0:
                        # Not enough edges to decide.
                        next_basepoint = True
                        break
                    # Update the mappings between the old and new indices.
                    if old_to_new[b] == 0:
                        next_index += 1
                        old_to_new[b] = next_index
                        new_to_old[next_index] = b
                    #Compare the old and new indices of the other end of the edge
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

cdef class SimsTree:
    """
    A "tree" of CoveringSubgraphs constructed by Sims algorithm.  Each
    CoveringSubgraph in the tree is constructed by adding edges to its parent in
    such a way that every relation that can be lifted lifts to a loop.  (It is
    allowed for a relation to fail to lift because an edge is missing from the
    subgraph.)

    Implementation note: The collection of all graphs produced by Sims algorithm
    can be viewed as a tree, where the children of each node are each obtained
    by adding edges to the node.  However, only the tips of the tree are of
    interest.  So we actually implement the "tree" as a python list.  Each
    pass through the loop in the bloom method generates a new list by replacing
    each subgraph by a list of subgraphs obtained by adding edges.

    >>> from fpgroups import *
    >>> t = SimsTree(rank=1, max_degree=3)
    >>> len(t)
    3
    >>> for g in t: print(g)
    ...
    Covering graph with edges:
    1--1->1
    Covering graph with edges:
    1--1->2
    2--1->1
    Covering graph with edges:
    1--1->2
    2--1->3
    3--1->1
    >>> t = SimsTree(rank=2, max_degree=3)
    >>> len(t)
    11
    >>> print(t[7])
    Covering graph with edges:
    1--1->2
    1--2->1
    2--1->3
    2--2->2
    3--1->1
    3--2->3

    """
    cdef int rank
    cdef int max_degree
    cdef CoveringSubgraph root
    cdef char done
    cdef public list nodes
    cdef public list relators
    # Workspaces used by CoveringSubgraphs when checking minimality
    cdef unsigned char *old_to_new
    cdef unsigned char *new_to_old

    def __cinit__(self,  int rank=1, int max_degree=1, relators=[]):
        self.old_to_new = <unsigned char*>PyMem_Malloc(self.max_degree + 1)
        self.new_to_old = <unsigned char*>PyMem_Malloc(self.max_degree + 1)

    def __dealloc__(self):
        PyMem_Free(self.old_to_new)
        PyMem_Free(self.new_to_old)

    def __init__(self, int rank=1, int max_degree=1, relators=[]):
        self.rank = rank
        self.max_degree = max_degree
        self.relators = [CyclicallyReducedWord(r, self.rank) for r in relators]
        self.root = CoveringSubgraph(rank=rank, max_degree=max_degree,
                                         num_relators=len(relators))
        self.nodes = [self.root]
        self.bloom()

    def __len__(self):
        return len(self.nodes)

    def __getitem__(self, index):
        return self.nodes[index]

    def __iter__(self):
        return iter(self.nodes)

    cdef bloom(self):
        cdef CoveringSubgraph tip
        cdef int count = 0
        cdef list new_nodes
        cdef list sprouts
        while True:
            count = 0
            new_nodes = []
            for tip in self:
                sprouts = tip.sprout(self)
                count += len(sprouts)
                if sprouts:
                    new_nodes += sprouts
                elif tip.is_complete():
                    new_nodes.append(tip)
            if count == 0:
                break
            self.nodes = new_nodes
