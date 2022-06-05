#ifndef _SIMS_NODE_H
#define _SIMS_NODE_H

#include "coveringSubgraph.h"

class SimsNode : public CoveringSubgraph
{
public:
    SimsNode(int rank, int max_degree, int num_relators = 0);

    bool relators_may_lift(SimsNode * child,
                           const std::vector<std::vector<int>> &relators);
    void sprout(const std::vector<std::vector<int>> &relators);

    std::vector<SimsNode> _children;

private:
    std::vector<VertexIndexType> _lift_indices;
    std::vector<VertexIndexType> _lift_vertices;

};

#endif
