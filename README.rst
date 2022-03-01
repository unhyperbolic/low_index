FPGroups
========

The FPGroups project aims to provide a Python module which implements
standard algorithms related to finitely presented groups.  It will be
included as a component of a future release of SnapPy.

Currently the fpgroups module provides an implementation of a variant
of Charles Sims' algorithm for enumerating low index subgroups of a
finitely presented group up to conjugacy.

Here is a sample computation:

.. code-block:: python

    >>> from fpgroups import *
    >>>  # Conjugacy classes of index 4 subgroups of F_3: 
    >>> sgps = SimsTree(3, 4).list()
    >>> len(sgps)
    653
    >>> from snappy import *
    >>> G = Manifold('K11n34').fundamental_group()
    >>> G
    Generators:
       a,b,c
    Relators:
       aaBcbbcAc
       aacAbCBBaCAAbbcBc
    >>> # Degree 7 covers of the exterior of the Conway knot:
    >>> sgps = SimsTree(G.num_generators(), 7, G.relators()).list()
    >>> len(sgps) 
    52
    >>> sgps[25].permutation_rep()
    [[1, 0, 3, 5, 2, 4], [0, 2, 4, 1, 5, 3], [2, 3, 4, 0, 1, 5]]


Credits
=======

Primarily developed by `Marc Culler <https://marc-culler.info>`_,
`Nathan Dunfield <http://dunfield.info>`_, and `Matthias Goerner
<http://www.unhyperbolic.org/>`_

License
=======

Copyright 2022 by Marc Culler, Nathan Dunfield, Matthias Goerner
and others.

This code is released under the `GNU General Public License, version 2
<http://www.gnu.org/licenses/gpl-2.0.txt>`_ or (at your option) any
later version as published by the Free Software Foundation.

