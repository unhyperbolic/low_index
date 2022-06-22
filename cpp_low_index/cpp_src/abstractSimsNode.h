#ifndef LOW_INDEX_ABSTRACT_SIMS_NODE_H
#define LOW_INDEX_ABSTRACT_SIMS_NODE_H

#include "coveringSubgraph.h"

namespace low_index {

///
/// A covering subgraph with additional methods to check whether
/// the given relators lift and whether the covering subgraph is
/// minimal in the conjugation class with respect to a certain
/// ordering.
///
/// We say that a relator lifts to a covering subgraph if starting
/// with any vertex and traversing the edges in the order such that
/// their labels spell out the relator word.
///
/// Note that we have two methods to check whether a set of relators
/// lifts. The method relators_may_lift makes use of an acceleration
/// structure to repeatedly query the same relators and can be called
/// on an incomplete subgraph. Also note that relators_may_lift can
/// add edges to the graph itself - called a deducation.
/// relators_lift does not use any acceleration
/// structure and can only be called on a complete subgraph.
///
/// We call the relators passed to relators_may_lift the "short relators"
/// and the ones passed to relators_lift the "long relators" - even
/// though it is not a requirement that the "short relators" are
/// actually shorter than the "long relators", but the low index
/// algorithm tends to perform better when the "short relators" are
/// indeed short.
///
/// Similarly to CoveringSubgraph, this is an abstract class
/// with AbstractSimsNode::_lift_indices and AbstractSimsNode::_lift_vertices
/// being managed by a subclass of AbstractSimsNode.
///
class AbstractSimsNode : public CoveringSubgraph
{
public:
    /// Check that given "long" relators lift. Requires that the
    /// subgraph is complete.
    bool relators_lift(const std::vector<Relator> &relators) const;

    /// Check that the given "short" relators lift. Does not
    /// require that the subgraph is complete. The method is using
    /// the acceleration structure. Thus, the vector of relators
    /// given to this class must always be the same and its length
    /// must match the num_relators argument given when the class
    /// was instantiated.
    ///
    /// If the subgraph is complete, the answer is definite. That
    /// is, if the subgraph is complete then the answer is true
    /// if and only if the given relators lift.
    bool relators_may_lift(const std::vector<Relator> &relators);

    /// We regard two complete covering subgraphs that differ only
    /// by reindexing of the vertices as equivalent. We want to only
    /// list one complete covering subgraph for each such conjugacy
    /// class. There is an order on covering subgraphs.
    /// 
    /// This method returns false if and only if no completion of
    /// this covering subgraph to a complete graph can be minimal
    /// in its conjugacy class with respect to the above order.
    ///
    /// Note that this method only works correctly if the edges were
    /// added in a particular order, namely, by always picking an
    /// edge starting at CoveringSubgraph::first_empty_slot next.
    ///
    /// If the subgraph is complete, the answer is definite. That
    /// is, if the subgraph is complete, then the answer is true
    /// if and only if the given relators lift.
    bool may_be_minimal() const;

    /// How many relators are supported by the acceleration structure.
    /// In other words, the number of "short relators".
    unsigned int num_relators() const { return _num_relators; }

protected:
    AbstractSimsNode(RankType rank,
                     DegreeType max_degree,
                     unsigned int num_relators);

    AbstractSimsNode(const AbstractSimsNode &other);

    struct _MemoryLayout
    {
        _MemoryLayout(const AbstractSimsNode &node);

        static constexpr size_t outgoing_offset = 0;
        size_t incoming_offset;
        size_t lift_indices_offset;
        size_t lift_vertices_offset;
        size_t size;
    };

    void _apply_memory_layout(const _MemoryLayout &layout,
                              uint8_t * memory);
    void _initialize_memory();
    void _copy_memory(const AbstractSimsNode &other);

private:
    bool _relator_may_lift(
        const Relator &relator,
        size_t n,
        DegreeType v);

    bool _may_be_minimal(DegreeType basepoint) const;

    const unsigned int _num_relators;

public:
    size_t _memory_size;
    RelatorLengthType *_lift_indices;
    DegreeType *_lift_vertices;
};

} // Namespace low_index

#endif
