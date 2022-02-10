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
  edge with initial vertex i and label j.  This is called the matrix of outies.
  A related DxG matrix, the matrix of innies, is the one for which the (i,j)
  entry is the index of the initial vertex of the edge with terminal vertex i
  and label j.  For efficiency we use and maintain both of these, even though
  they carry the same information. All entries of these matrices will be
  non-zero.

- While constructing covers we need to work with subgraphs of the 1-skeletion.
  A subgraph can be represented by a DxG matrix in which some of the entries are
  0.  The (i,j) entry of the matrix of outties is 0 if and only if there is no
  edge with initial vertex i and label j in the subgraph.  Similarly, the (i,j)
  entry of the matrix of innies is 0 if and only if there is no edge with
  terminal vertex i and label j.
"""

cdef class CoveringSubgraph:
    cdef int rank
    cdef int degree
    cdef int max_degree
    cdef int num_edges
    cdef unsigned char* outies
    cdef unsigned char* innies
    
    def __cinit__(self, rank, max_degree):
        self.degree = 1
        self.num_edges = 0
        self.rank = rank
        self.max_degree = max_degree
        cdef int size = self.rank*self.max_degree
        self.outies = <unsigned char *>PyMem_Malloc(size)
        memset(self.outies, 0, size)
        self.innies = <unsigned char *>PyMem_Malloc(size)
        memset(self.innies, 0, size)

    def __dealloc__(self):
        PyMem_Free(self.outies)
        PyMem_Free(self.innies)

    def __str__(self):
        cdef int t
        result = 'Covering graph with edges:\n'
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
        self.outies[out_index] = to_vertex
        self.innies[in_index] = from_vertex
        self.num_edges += 1

    cdef inline act_by(self, int letter, int vertex):
        if letter > 0:
            return self.outies[(vertex - 1)*self.rank + letter - 1]
        elif letter < 0:
            return self.innies[(vertex - 1)*self.rank - letter - 1]

    cdef first_empty_slot(self, int basepoint=1):
        cdef int v, l
        for n in range(self.rank*self.degree):
            if self.outies[n] == 0:
                v = n // self.rank
                l = n % self.rank
                return v + 1, l + 1
            if self.innies[n] == 0:
                v = n // self.rank
                l = n % self.rank
                return v + 1, -(l + 1)

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
    interest.  So we actually implement the "tree" as a python list.  In each
    cycle in the loop of the bloom method a new list is generated, replacing
    each node by a list of nodes whose graphs are obtained by adding edges.

>>> from fpgroups import *
>>> t = SimsTree(rank=1, max_degree=3)
>>> len(t)
3
>>> for g in t.covers(): print(g)
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
>>> print(t.covers()[7])
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
    cdef SimsNode root
    cdef SimsNode next
    cdef char done
    cdef public list nodes
    # Workspaces used by SimsNodes when checking minimality
    cdef unsigned char *old_to_new
    cdef unsigned char *new_to_old

    def __cinit__(self):
        self.old_to_new = <unsigned char*>PyMem_Malloc(self.max_degree + 1)
        self.new_to_old = <unsigned char*>PyMem_Malloc(self.max_degree + 1)

    def __dealloc__(self):
        PyMem_Free(self.old_to_new)
        PyMem_Free(self.new_to_old)

    def __init__(self, int rank=1, int max_degree=1):
        self.rank = rank
        self.max_degree = max_degree
        subgraph=CoveringSubgraph(rank=rank, max_degree=max_degree)
        self.root = SimsNode(subgraph, tree=self)
        self.nodes = [self.root]
        self.bloom()

    def __len__(self):
        return len(self.nodes)

    def __iter__(self):
        return iter(self.nodes)

    def covers(self):
        return [n.subgraph for n in self.nodes]

    cdef bloom(self):
        cdef SimsNode tip
        cdef int count = 0
        cdef list new_nodes
        cdef list sprouts
        while True:
            count = 0
            new_nodes = []
            for tip in self:
                sprouts = tip.sprout()
                count += len(sprouts)
                if sprouts:
                    new_nodes += sprouts
                elif tip.subgraph.is_complete():
                    new_nodes.append(tip)
            if count == 0:
                break
            self.nodes = new_nodes

cdef class SimsNode:
    """
    A node in a SimsTree, containing a based partial covering.
    """
    cdef SimsTree tree
    cdef public CoveringSubgraph subgraph

    def __init__(self, subgraph, tree=None, parent=None):
        self.subgraph = subgraph
        self.tree = tree

    cdef sprout(self):
        """
        Find the first empty edge slot in this based partial covering.  For each
        possible way to add an edge in that slot, create a new node containing
        the subgraph obtained by adding that edge.  Return the list of new nodes.
        """
        cdef int n, v, l
        cdef CoveringSubgraph new_subgraph, g = self.subgraph
        cdef SimsNode new_leaf
        cdef list children = []
        try:
            v, l = g.first_empty_slot()
        except TypeError:
            return []
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
        for l, v, n in targets:
            new_subgraph = g.clone()
            new_subgraph.add_edge(l, v, n)
            new_leaf = SimsNode(new_subgraph, tree=self.tree, parent=self)
            if new_leaf.keep():
                children.append(new_leaf)
        return children

    cdef keep(self):
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
        cdef unsigned char *old_to_new = self.tree.old_to_new
        cdef unsigned char *new_to_old = self.tree.new_to_old
        cdef int basepoint, next_basepoint, old_index, new_index, next_index
        cdef int degree = self.subgraph.degree, rank = self.subgraph.rank
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
