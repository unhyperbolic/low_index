#include "heapedSimsNode.h"

HeapedSimsNode::HeapedSimsNode(RankType rank,
                   DegreeType max_degree,
                   unsigned int num_relators)
      : HeapStorage(2 * rank * max_degree * sizeof(DegreeType) + num_relators * max_degree * (sizeof(RelatorLengthType) + sizeof(DegreeType)))
      , SimsNode(rank, max_degree, num_relators)
{
    _ApplyMemoryLayout(_MemoryLayout(rank, max_degree, num_relators), _get_mem());
    _InitializeMemory();
}

