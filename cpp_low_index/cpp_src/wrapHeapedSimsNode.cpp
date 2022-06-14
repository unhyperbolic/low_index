#include "heapedSimsNode.h"

#include "pybind11/pybind11.h"

#include "pybind11/stl.h"

void addHeapedSimsNode(pybind11::module_ &m) {
    pybind11::class_<HeapStorage>(m, "HeapStorage");
    
    pybind11::class_<HeapedSimsNode, HeapStorage, SimsNode>(m, "HeapedSimsNode");
}
