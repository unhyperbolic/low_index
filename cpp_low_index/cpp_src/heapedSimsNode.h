#ifndef _HEAPED_SIMS_NODE_H_
#define _HEAPED_SIMS_NODE_H_

#include "simsNode.h"

#include <memory>

class HeapStorage
{
protected:
    HeapStorage(const size_t n) : _data(new uint8_t[n]) { }

    uint8_t * _get_mem() { return _data.get(); }
    
private:
    std::unique_ptr<uint8_t[]> _data;
};

class HeapedSimsNode : public HeapStorage, public SimsNode
{
public:
    HeapedSimsNode(RankType rank,
                   DegreeType max_degree,
                   unsigned int num_relators)
      : HeapStorage(2 * rank * max_degree * sizeof(DegreeType) + num_relators * max_degree * (sizeof(RelatorLengthType) + sizeof(DegreeType)))
      , SimsNode(rank, max_degree, num_relators, _get_mem())
    {
        const _MemoryLayout layout(rank, max_degree, num_relators);
        outgoing = _get_mem() + layout.outgoing_offset;
        
    }

    HeapedSimsNode(const HeapedSimsNode &other)
      : HeapStorage(2 * other.rank * other.max_degree * sizeof(DegreeType) + other.num_relators * other.max_degree * (sizeof(RelatorLengthType) + sizeof(DegreeType)))
      , SimsNode(other, _get_mem())
    {
    }

    HeapedSimsNode(const SimsNode &other)
      : HeapStorage(2 * other.rank * other.max_degree * sizeof(DegreeType) + other.num_relators * other.max_degree * (sizeof(RelatorLengthType) + sizeof(DegreeType)))
      , SimsNode(other, _get_mem())
    {
    }
};

#endif
