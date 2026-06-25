# Development

This repository includes a `Makefile` for the example document and test suite.

To build [`manbib.tex`](./manbib.tex) and refresh [`README.tex`](./README.tex) from [`README.md`](./README.md), run:

    make

This will create [`manbib.pdf`](./manbib.pdf) along with the managed bibliography file [`manbib.adskeys.bib`](./manbib.adskeys.bib).

To clean the generated LaTeX files, run:

    make clean

To run the Perl test suite, run:

    make test

To remove a fuller set of generated files, run:

    make distclean
