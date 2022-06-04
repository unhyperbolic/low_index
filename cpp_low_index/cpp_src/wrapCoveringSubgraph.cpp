#include "coveringSubgraph.h"

#include "pybind11/pybind11.h"

void addCoveringSubgraph(pybind11::module_ &m) {
    pybind11::class_<CoveringSubgraph>(m, "CoveringSubgraph")
        .def(pybind11::init<int, int, int>(),
             pybind11::arg("rank"),
             pybind11::arg("max_degree"),
             pybind11::arg("num_relators") = 0)
        .def_readonly("rank", &CoveringSubgraph::rank)
        .def("is_complete", &CoveringSubgraph::is_complete)
        .def("add_edge", &CoveringSubgraph::add_edge)
        .def("verified_add_edge", &CoveringSubgraph::verified_add_edge)
        .def("to_string", &CoveringSubgraph::to_string);
}
