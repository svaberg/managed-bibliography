# Development

This file is only for developing this repository itself. The commands below are for rebuilding the example documentation PDF and running the test suite in this checkout.

Users of `managed-bibliography.pl` do not need to worry about this build setup. In particular, they do not need this repository `Makefile`, the LuaLaTeX path below, or the pdfLaTeX shell-escape test path just to use the script in their own document directory.

To build [`manbib.tex`](./manbib.tex) from [`README.md`](./README.md), run:

    make

This will create [`manbib.pdf`](./manbib.pdf) along with the managed bibliography file [`manbib.adskeys.bib`](./manbib.adskeys.bib).

The default build path uses LuaLaTeX through [`latexmk`](https://ctan.org/pkg/latexmk/):

    latexmk -lualatex -bibtex manbib.tex

If you need to test the pdfLaTeX path instead, the Markdown package also works here with shell escape enabled:

    latexmk -pdf -shell-escape -bibtex manbib.tex

To clean the generated LaTeX files, run:

    make clean

To run the Perl test suite, run:

    make test

To remove a fuller set of generated files, run:

    make distclean

To remove the managed bibliography file itself, either delete [`manbib.adskeys.bib`](./manbib.adskeys.bib) by hand or run `make distclean`.
