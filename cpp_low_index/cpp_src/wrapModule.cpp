#include "wrapCoveringSubgraph.cpp"

void addCoveringSubgraph(pybind11::module_ &m);

PYBIND11_MODULE(low_index, m) {
    addCoveringSubgraph(m);
}
