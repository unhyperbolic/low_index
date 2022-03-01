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

    def __cinit__(self, int rank, int max_degree, int num_relators=0,
                  bytes outgoing=b'', bytes incoming=b'',
                  bytes lift_indices=b'', bytes lift_vertices=b''):
        cdef int n = 0, degree = 1
        cdef unsigned char b
        self.degree = 1
        self.num_edges = 0
        self.rank = rank
        self.max_degree = max_degree
        self.num_relators = num_relators
        cdef int size = rank*max_degree
        self.outgoing = <unsigned char *>PyMem_Malloc(size)
        memset(self.outgoing, 0, size)
        self.incoming = <unsigned char *>PyMem_Malloc(size)
        memset(self.incoming, 0, size)
        if outgoing:
            while n < size:
                b = outgoing[n]
                if b > degree:
                    degree = b
                self.outgoing[n] = b
                c = incoming[n]
                self.incoming[n] = c
                if c > degree:
                    degree = c
                n += 1
                if b > 0:
                    self.num_edges += 1
            self.degree = degree

    def __dealloc__(self):
        PyMem_Free(self.outgoing)
        PyMem_Free(self.incoming)

    def __str__(self):
        cdef int t
        if self.is_complete():
            result = 'Covering with edges:\n'
        else:
            result = 'Partial covering with edges:\n'
        for f in range(self.degree):
            for n in range(self.rank):
                 t = self.outgoing[f*self.rank + n]
                 if t:
                     result += '%d--%d->%d\n'%(f + 1, n + 1, t)
        return result[:-1]

    def __reduce__(self):
        cdef int size = self.rank*self.max_degree
        return (self.__class__,
                (self.rank, self.max_degree, self.num_relators,
                     self.outgoing[:size], self.incoming[:size]))

    def _data(self):
        print('out:', [n for n in self.outgoing[:self.rank*self.degree]])
        print('in:', [n for n in self.incoming[:self.rank*self.degree]])

    def __key__(self):
        return self.outgoing[:self.rank*self.degree]

    def __hash__(self):
        return hash(self.__key__())

    def __eq__(SimsNode self, SimsNode other):
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

    cdef inline _is_complete(self):
        return self.num_edges == self.rank*self.degree

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

    cdef first_empty_slot(self):
        cdef int v, l
        cdef div_t qr
        cdef unsigned char *incoming = self.incoming
        cdef unsigned char *outgoing = self.outgoing
        for n in range(self.rank*self.degree):
            if outgoing[n] == 0:
                qr = div(n, self.rank)
                v = qr.quot
                l = qr.rem
                return (v + 1, l + 1)
            if incoming[n] == 0:
                qr = div(n, self.rank)
                v = qr.quot
                l = qr.rem
                return (v + 1, -(l + 1))
        return (0,0)

    cdef inline int _first_empty_slot(self):
        cdef int v, l
        cdef div_t qr
        cdef unsigned char *incoming = self.incoming
        cdef unsigned char *outgoing = self.outgoing
        for n in range(self.rank*self.degree):
            if outgoing[n] == 0:
                qr = div(n, self.rank)
                v = qr.quot
                l = qr.rem
                return ((l + 1) << 8) | (v + 1)
            if incoming[n] == 0:
                qr = div(n, self.rank)
                v = qr.quot
                l = qr.rem
                return (-(l + 1) << 8) | (v + 1)
        return 0

cdef class SimsNode(CoveringSubgraph):
    cdef unsigned char* state_info
    cdef unsigned char* lift_indices
    cdef unsigned char* lift_vertices

    def __cinit__(self, int rank, int max_degree, int num_relators=0,
                  bytes outgoing=b'', bytes incoming=b'',
                  bytes lift_indices=b'', bytes lift_vertices=b''):
        cdef int n
        if num_relators > 0:
            # Maintain per-vertex state for each relator and its inverse.
            size = num_relators*max_degree
            self.state_info = <unsigned char *>PyMem_Malloc(2*size)
            memset(self.state_info, 0, 2*size)
            self.lift_indices = self.state_info
            self.lift_vertices = &self.state_info[size]

            if lift_indices:
                for n, c in enumerate(lift_indices):
                    self.state_info[n] = c

            if lift_vertices:
                for n, c in enumerate(lift_vertices):
                    self.state_info[size + n] = c


    def __dealloc__(self):
        if self.num_relators:
            PyMem_Free(self.state_info)

    def __str__(self):
        cdef int t
        result = 'SimsNode with edges:\n'
        for f in range(self.degree):
            for n in range(self.rank):
                 t = self.outgoing[f*self.rank + n]
                 if t:
                     result += '%d--%d->%d\n'%(f + 1, n + 1, t)
        return result[:-1]

    def __reduce__(self):
        cdef int size = self.rank*self.max_degree
        data = (self.rank, self.max_degree, self.num_relators,
                self.outgoing[:size], self.incoming[:size])
        if self.num_relators:
            data = data + (self.lift_indices[:size], self.lift_vertices[:size])
        return (self.__class__, data)

    cdef clone(self):
        cdef result = SimsNode(self.rank, self.max_degree, self.num_relators)
        self._copy_in_place(result)
        return result

    cdef _copy_in_place(SimsNode self, SimsNode other):
        # These must have the same rank, max_degree, and num_relators
        # We do not check!
        cdef int size = self.rank*self.max_degree
        other.degree = self.degree
        other.num_edges = self.num_edges
        other.num_relators = self.num_relators
        memcpy(other.outgoing, self.outgoing, size)
        memcpy(other.incoming, self.incoming, size)
        if self.num_relators > 0:
            size = 2*self.num_relators*self.max_degree
            memcpy(other.state_info, self.state_info, size)

    cdef sprout(self, SimsTree tree):
        """
        Find the first empty edge slot in this based partial covering.  For each
        possible way to add an edge in that slot, create a new node containing
        the subgraph obtained by adding that edge.  Return the list of new nodes.
        """
        cdef int n, v, l, i, slot
        cdef int rank=self.rank
        cdef int degree = self.degree
        cdef int max_degree = self.max_degree
        cdef unsigned char *incoming = self.incoming
        cdef unsigned char *outgoing = self.outgoing
        cdef SimsNode new_subgraph
        cdef list children = []
        slot = self._first_empty_slot()
        if slot == 0:
            return children
        v = slot & 0xff
        l = slot >> 8
        targets = []
        # Add an edge to a new vertex if allowed. (It will be processed last.)
        if degree < max_degree:
            targets.append((l, v, degree + 1))
        # Add edges with from this slot to all possible target slots.
        if l > 0:
            i = 0
            for n in range(degree):
                t = incoming[i + l - 1]
                i += rank
                if t == 0:
                    targets.append((l, v, n+1))
        else:
            i = 0
            for n in range(degree):
                t = outgoing[i - l - 1]
                i += rank
                if t == 0:
                    targets.append((l, v, n+1))
        for l, v, n in targets:
            new_subgraph = tree.get_node()
            self._copy_in_place(new_subgraph)
            new_subgraph.add_edge(l, v, n)
            if (self.relators_may_lift(new_subgraph, tree)
                and new_subgraph.may_be_minimal(tree)):
                children.append(new_subgraph)
            else:
                tree.cache.append(new_subgraph)
        return children

    cdef relators_may_lift(self, SimsNode child, SimsTree tree):
        """
        Check that when any relator is lifted to any vertex of a child graph it
        either lifts to a loop or runs into a missing edge. This subgraph uses
        its saved state as the starting point for checking the child.
        """
        cdef CyclicallyReducedWord w
        cdef char l
        cdef unsigned char index, vertex, save, length
        cdef int n = 0, v, i = 0, j
        cdef int rank = child.rank, max_degree = child.max_degree
        for w in tree.relators:
            length = w.length
            for v in range(child.degree):
                # Check whether relator n lifts to a loop at vertex v + 1.
                j = n*max_degree + v
                index = self.lift_indices[j]
                if index >= length:
                    # We already checked that the relator lifts to a loop.
                    continue
                vertex = self.lift_vertices[j]
                if vertex == 0:
                    # The state is uninitialized.
                    vertex = v + 1
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
                elif i == length - 1:
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

    cdef may_be_minimal(self, SimsTree tree):
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
        cdef unsigned char *std_to_alt = tree.std_to_alt
        cdef unsigned char *alt_to_std = tree.alt_to_std
        cdef int basepoint, max_index
        cdef int slot_vertex, slot_label
        cdef int degree = self.degree, rank = self.rank
        cdef int a, b, c
        cdef unsigned char *outgoing = self.outgoing
        cdef unsigned char *incoming = self.incoming
        for basepoint in range(2, degree + 1):
            # We are working with the standard indexing (determined by putting
            # the basepoint at vertex 1) and an alternate indexing determined by
            # a different basepoint.  We construct mappings between the two
            # indexings and store them in the arrays std_to_alt and
            # alt_to_std. (For convenience when dealing with 1-based indices,
            # just ignore the 0 entry).
            memset(std_to_alt, 0, degree + 1)
            # It is not necessary to clear alt_to_std
            #memset(alt_to_std, 0, degree + 1)
            # Initial state.
            std_to_alt[basepoint] = 1
            alt_to_std[1] = basepoint
            max_index = 1
            slot_vertex = 1
            slot_label = 0
            # Iterate over all possible slots.
            while slot_vertex <= degree and slot_label < 2*self.rank:
                # Check that the slot is filled with repect to both indexings.
                sign = slot_label & 0x1
                l = slot_label >> 1
                if sign == 0: # positive label
                    a = outgoing[(slot_vertex - 1)*rank + l]
                    b = outgoing[(alt_to_std[slot_vertex] - 1)*rank + l]
                else: # negative label
                    a = incoming[(slot_vertex - 1)*rank + l]
                    b = incoming[(alt_to_std[slot_vertex] - 1)*rank + l]
                if a == 0 or b == 0:
                    # The slot was empty in one indexing, so we cannot decide.
                    break
                # Update the mappings.
                if std_to_alt[b] == 0:
                    # This edge is the first, with respect to the alternate
                    # indexing, that is incident to the vertex with standard
                    # index b.  We now know its alternate index.
                    max_index += 1
                    std_to_alt[b] = max_index
                    alt_to_std[max_index] = b
                #Compare the old and new indices of the other end of the edge
                c = std_to_alt[b]
                if c < a:
                    # The new basepoint is better - discard this graph.
                    return False
                if c > a:
                    # The old basepoint is better - try the next one.
                    break
                # Increment the slot.
                slot_label += 1
                if slot_label == 2*rank:
                    slot_label = 0
                    slot_vertex += 1
        return True

cdef class SimsTreeIterator:
    cdef SimsTree tree
    cdef list stack
    cdef int rank, max_degree, num_relators

    def __init__(self, SimsTree tree):
        self.tree = tree
        self.rank = tree.rank
        self.max_degree = tree.max_degree
        self.num_relators = len(tree.relators)
        self.stack = []
        self.push(tree.root)

    def __next__(self):
        cdef node = self._next()
        if node is None:
            self.tree.cache = []
            raise StopIteration
        return node

    cdef inline _next(self):
        cdef list sprouts
        cdef SimsNode top, node
        while True:
            if not self.stack:
                return None
            # Peek at the top of the stack.
            top, sprouts = self.stack[-1]
            # If the top graph is complete, pop it, cache it, and clone it.
            if top._is_complete():
                node = self.pop()
                self.tree.cache.append(node)
                return node.clone()
            # If there are unvisited children, visit the next one.
            if sprouts:
                self.push(sprouts.pop())
            # Otherwise, ascend to a node with unvisited children.  Be sure
            # to cache any nodes that get popped from our stack.
            else:
                while True:
                    if not self.stack:
                        return None
                    # Take a peek to see if there are unvisited children.
                    top, sprouts = self.stack[-1]
                    if not sprouts:
                        self.pop(recycle=1)
                    else:
                        break

    cdef push(SimsTreeIterator self, SimsNode node):
        cdef list sprouts = node.sprout(self.tree)
        self.stack.append((node, sprouts))

    cdef pop(SimsTreeIterator self, int recycle=0):
        cdef SimsNode top
        cdef list sprouts
        top, sprouts = self.stack.pop()
        if recycle == 0:
            return top
        self.tree.cache.append(top)

cdef class SimsTree:
    """
    A "tree" of SimsNodes constructed by Sims algorithm.  Each
    SimsNode in the tree is constructed by adding edges to its parent in
    such a way that every relation that can be lifted lifts to a loop.  (It is
    allowed for a relation to fail to lift because an edge is missing from the
    subgraph.)

    Implementation note: The collection of all graphs produced by Sims algorithm
    can be viewed as a tree, where the children of a node are obtained by adding
    one edge at the first empty slot.  However, only the tips of the tree are of
    interest.  So we can implement the "tree" as a python list.  Each pass
    through the loop in the (currently unused) bloom method generates a new list
    by replacing each subgraph by a list of subgraphs obtained by adding edges.
    This turns out to be very memory intensive, since these lists grow very
    large before finally collapsing at the end of the computation.  We also
    provide an iterator which iterates through the tips of the tree while using
    a constant amount of memory.  The depth of the tree is bounded by the number
    of edges in a cover of the maximal allowed degree.  Traversal of the tree in
    depth-first order only requires a stack of size equal to the maximum depth.

    >>> from fpgroups import *
    >>> t = SimsTree(rank=1, max_degree=3).list()
    >>> len(t)
    3
    >>> for g in t: print(g)
    ...
    Sims Node with edges:
    1--1->2
    2--1->3
    3--1->1
    Sims Node with edges:
    1--1->2
    2--1->1
    Sims Node with edges:
    1--1->1
    >>> t = SimsTree(rank=2, max_degree=3).list()
    >>> len(t)
    11
    >>> print(t[7])
    Sims Node with edges:
    1--1->1
    1--2->2
    2--1->2
    2--2->3
    3--1->3
    3--2->1
    """
    cdef public int rank
    cdef public int max_degree
    cdef public SimsNode root
    cdef public list nodes
    cdef public list relators
    cdef public list orig_relators
    cdef public str strategy
    cdef int num_relators
    cdef list cache
    # Temporary workspace used by SimsNodes when checking minimality.
    cdef unsigned char *std_to_alt
    cdef unsigned char *alt_to_std

    def __cinit__(self,  int rank=1, int max_degree=1, relators=[],
                      strategy=None, root=None):
        self.std_to_alt = <unsigned char*>PyMem_Malloc(self.max_degree + 1)
        self.alt_to_std = <unsigned char*>PyMem_Malloc(self.max_degree + 1)

    def __dealloc__(self):
        PyMem_Free(self.std_to_alt)
        PyMem_Free(self.alt_to_std)

    def __init__(self, int rank=1, int max_degree=1, relators=[],
                     strategy=None, root=None):
        self.rank = rank
        self.max_degree = max_degree
        self.strategy = strategy
        self.orig_relators = [r for r in relators]
        if strategy == 'spin_short':
            relators = self.spin_short_relators(relators)
        self.relators = [CyclicallyReducedWord(r, self.rank) for r in relators]
        self.num_relators = len(self.relators)
        if isinstance(root, bytes):
            self.root = pickle.loads(root)
        elif isinstance(root, SimsNode):
            self.root = root
        else:
            self.root = SimsNode(rank=rank, max_degree=max_degree,
                                 num_relators=self.num_relators)
        self.nodes = [self.root]
        self.cache = []

    def __iter__(self):
        return SimsTreeIterator(self)

    def __reduce__(self):
        relators = [str(r) for r in self.relators]
        return (self.__class__,
                (self.rank, self.max_degree, relators, self.strategy,
                pickle.dumps(self.root))
                )

    def plant(self, SimsNode node):
        """
        Construct a SimsTree with the given node as its root, using the
        same rank, max_degree, relators and strategy.
        """
        cdef list relators = [str(r) for r in self.relators]
        return SimsTree(self.rank, self.max_degree, relators, root=node)

    cdef get_node(SimsTree self):
        """
        If possible, reuse cached SimsNodes to avoid needless construction
        and destruction of nodes.
        """
        if self.cache:
            return self.cache.pop()
        return SimsNode(self.rank, self.max_degree, self.num_relators)

    cdef spin(self, str word):
        return [word[k:] + word[:k] for k in range(len(word))]

    def spin_short_relators(self, relators):
        result = []
        if relators:
            avg = sum(len(r) for r in relators) / len(relators)
            for r in relators:
                if len(r) <= avg:
                    result += self.spin(r)
                else:
                    result.append(r)
        return sorted(result, key=lambda x : len(x))

    cpdef list(self):
        """
        Return a list created from this tree's iterator.  We call the C
        implementation of the iterator's next method directly.
        """
        cdef list result = []
        cdef SimsTreeIterator iterator = SimsTreeIterator(self)
        cdef SimsNode node
        while True:
            node = iterator._next()
            if node is None:
                break
            result.append(node)
        return result

    def list_mp(self, int depth=2):
        """
        Compute the list of covers with a pool of worker processes.
        """
        result = []
        relator_strings = [str(r) for r in self.orig_relators]
        args = [sys.executable, multi.__file__, str(self.rank),
                str(self.max_degree), str(depth)] + relator_strings
        output = run(args, capture_output=True, encoding='ascii')
        for line in output.stdout.split('\n'):
            if line:
                p = eval(line)
                result.append(pickle.loads(p))
        return result

    # This method uses too much memory to be used in the list method, but is
    # used to seed the multiprocessing list method.  Starting from a list
    # containing only the root node of a SimsTree it iteratively replaces each
    # node in the list with a sublist consisting of the children of the node.

    cpdef bloom(self, int depth=0):
        """
        Return a list of all nodes which are either complete with depth at most
        the parameter value, or not complete with depth equal to the depth
        parameter.
        """
        cdef SimsNode tip
        cdef int count = 0, level = 0
        cdef list new_nodes
        cdef list sprouts
        while True:
            count = 0
            new_nodes = []
            for tip in self.nodes:
                sprouts = tip.sprout(self)
                count += len(sprouts)
                if sprouts:
                    new_nodes += sprouts
                elif tip._is_complete():
                    new_nodes.append(tip)
            if count == 0:
                break
            self.nodes = new_nodes
            if depth and level > depth:
                break
            level += 1
        return self.nodes
