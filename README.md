# MO648MC962

Project developed for course [MO648MC962](http://www.ic.unicamp.br/~nfonseca/MO648/) of [University of Campinas](http://www.unicamp.br/unicamp/?language=en).
The project consists of a network simulation for comparing a few transport layer protocols on a typical datacenter scenario.

## Requirements

The project makes use of [ns-2](http://www.isi.edu/nsnam/ns/), and hence requires it. Besides the usual protocols shipped with ns-2, this project uses Stanford's new module for the DCTCP protocol. A patch to ns-2 can be found [here](http://simula.stanford.edu/%7Ealizade/Site/DCTCP.html). The project also uses awk scripts to process the generated network traces, as well as the [Gnuplot](http://gnuplot.sourceforge.net/) utility to generate comparing graphs.
