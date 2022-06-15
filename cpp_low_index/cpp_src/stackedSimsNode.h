#ifndef _STACKED_SIMS_TREE_H
#define _STACKED_SIMS_TREE_H

#include "simsNode.h"

class StackedSimsNode : public SimsNode
{
public:
    StackedSimsNode(const SimsNode &other, uint8_t * memory)
     : SimsNode(other)
    {
        _ApplyMemoryLayout(
            _MemoryLayout(
                other.rank, other.max_degree, other.num_relators),
            memory);
        _CopyMemory(other);
    }

    StackedSimsNode(const StackedSimsNode &other);
};

#endif
