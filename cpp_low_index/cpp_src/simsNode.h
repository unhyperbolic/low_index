#ifndef _SIMS_NODE_H
#define _SIMS_NODE_H

#include "coveringSubgraph.h"

class SimsNode : public CoveringSubgraph
{
public:
    using RelatorLengthType = uint16_t;

    SimsNode(RankType rank,
             DegreeType max_degree,
             unsigned int num_relators,
             uint8_t * memory);

    SimsNode(const SimsNode &other, uint8_t * memory);

    const unsigned int num_relators;

    bool relators_lift(const std::vector<std::vector<int>> &relators) const;
    bool relators_may_lift(const std::vector<std::vector<int>> &relators);
    bool may_be_minimal() const;

    size_t size;

private:
    bool _relator_may_lift(
        const std::vector<int> &relator,
        size_t n,
        DegreeType v);

    bool _may_be_minimal(DegreeType basepoint) const;

    RelatorLengthType *_lift_indices;
    DegreeType *_lift_vertices;

};

#endif
