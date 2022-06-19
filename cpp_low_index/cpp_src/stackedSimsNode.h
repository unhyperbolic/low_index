#ifndef LOW_INDEX_STACKED_SIMS_TREE_H
#define LOW_INDEX_STACKED_SIMS_TREE_H

#include "abstractSimsNode.h"

namespace low_index {

class StackedSimsNode : public AbstractSimsNode
{
public:
    StackedSimsNode(const StackedSimsNode &other);

private:
    void * operator new(size_t size) = delete;

    friend class SimsNodeStack;
    StackedSimsNode(const AbstractSimsNode &other, uint8_t * memory);
};

} // Namespace low_index

#endif
