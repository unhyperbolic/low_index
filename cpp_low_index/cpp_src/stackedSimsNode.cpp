#include "stackedSimsNode.h"

template<typename T>
static
T* _move_pointer(T* const p, const size_t n)
{
    return reinterpret_cast<T*>(reinterpret_cast<uint8_t*>(p) + n);
}

StackedSimsNode::StackedSimsNode(const StackedSimsNode &other)
  : SimsNode(other)
{
    outgoing = _move_pointer(other.outgoing, other.size);
    incoming = _move_pointer(other.incoming, other.size);
    _lift_indices = _move_pointer(other._lift_indices, other.size);
    _lift_vertices = _move_pointer(other._lift_vertices, other.size);
    size = other.size;

    _copy_memory(other);
}

StackedSimsNode::StackedSimsNode(
    const SimsNode &other,
    uint8_t * const memory)
 : SimsNode(other)
{
    const _MemoryLayout layout(*this);
    _apply_memory_layout(layout, memory);
    _copy_memory(other);
}
