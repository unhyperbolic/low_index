#ifndef _STACKED_SIMS_TREE_H
#define _STACKED_SIMS_TREE_H

#include "simsNode.h"

class StackedSimsNode : public SimsNode
{
public:
    StackedSimsNode(const SimsNode &other, uint8_t * memory)
     : SimsNode(other, memory)
    {
    }

    StackedSimsNode(const StackedSimsNode &other)
        : SimsNode(other, reinterpret_cast<uint8_t*>(other.outgoing) + 2 * other.rank * other.max_degree * sizeof(DegreeType) + other.num_relators * other.max_degree * (sizeof(RelatorLengthType) + sizeof(DegreeType)))
    {
    }
};

#endif
