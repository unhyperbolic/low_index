#ifndef _STACKED_SIMS_TREE_H
#define _STACKED_SIMS_TREE_H

#include "simsNode.h"

class StackedSimsNode : public SimsNode
{
public:
    StackedSimsNode(const StackedSimsNode &other);

private:
    friend class SimsNodeStack;
    StackedSimsNode(const SimsNode &other, uint8_t * memory);
};

#endif
