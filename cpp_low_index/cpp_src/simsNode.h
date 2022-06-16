#ifndef _SIMS_NODE_H_
#define _SIMS_NODE_H_

#include "coveringSubgraph.h"

class SimsNode : public CoveringSubgraph
{
public:
    using RelatorLengthType = uint16_t;

    bool relators_lift(const std::vector<std::vector<int>> &relators) const;
    bool relators_may_lift(const std::vector<std::vector<int>> &relators);
    bool may_be_minimal() const;
    const unsigned int num_relators;

    size_t size;

protected:
    SimsNode(RankType rank,
             DegreeType max_degree,
             unsigned int num_relators);

    SimsNode(const SimsNode &other);

    struct _MemoryLayout
    {
        _MemoryLayout(const SimsNode &node);

        static constexpr size_t outgoing_offset = 0;
        size_t incoming_offset;
        size_t lift_indices_offset;
        size_t lift_vertices_offset;
        size_t size;
    };

    void _apply_memory_layout(const _MemoryLayout &layout,
                              uint8_t * memory);
    void _initialize_memory();
    void _copy_memory(const SimsNode &other);

    bool _relator_may_lift(
        const std::vector<int> &relator,
        size_t n,
        DegreeType v);

    bool _may_be_minimal(DegreeType basepoint) const;

    RelatorLengthType *_lift_indices;
    DegreeType *_lift_vertices;
};

#endif
