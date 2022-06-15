#include "simsNodeStack.h"

SimsNodeStack::SimsNodeStack(const SimsNode &node)
  : _memory(
      std::make_unique<uint8_t[]>(
          1000 * 
          SimsNode::_MemoryLayout(
              node.rank, node.max_degree, node.num_relators).size))
  , _node(node, _memory.get())
{
}
