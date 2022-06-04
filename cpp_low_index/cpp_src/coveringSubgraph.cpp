#include "coveringSubgraph.h"

CoveringSubgraph::CoveringSubgraph(
        const int rank,
        const int max_degree,
        const int num_relators)
  : rank(rank)
  , degree(0)
  , max_degree(max_degree)
  , num_edges(0)
  , num_relators(num_relators)
  , outgoing(rank * max_degree, 0)
  , incoming(rank * max_degree, 0)
  , _slot_index(0)
{
}
