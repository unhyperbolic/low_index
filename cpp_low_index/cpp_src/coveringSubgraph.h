#ifndef _COVERING_SUBGRAPH_H_
#define _COVERING_SUBGRAPH_H_

#include <vector>

class CoveringSubgraph
{
public:
    using IntType = unsigned char;

    CoveringSubgraph(int rank,
                     int max_degree,
                     int num_relators = 0);

    const int rank;
    int degree;
    const int max_degree;
    int num_edges;
    const int num_relators;
    std::vector<IntType> outgoing;
    std::vector<IntType> incoming;

protected:
    int _slot_index;
};

#endif
