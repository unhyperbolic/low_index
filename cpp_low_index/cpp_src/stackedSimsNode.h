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
     : SimsNode(other, reinterpret_cast<uint8_t*>(other.outgoing) + other.size)
    {
    }
};

#endif
