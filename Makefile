.PHONY: all test clean distclean

LATEXMK ?= latexmk
PANDOC ?= pandoc
PROVE ?= prove

all: manbib.pdf

README.tex: README.md
	$(PANDOC) --from=gfm README.md -o README.tex

manbib.pdf: README.tex manbib.tex managed-bibliography.pl latexmkrc
	$(LATEXMK) -pdf -bibtex manbib.tex

test:
	$(PROVE) -lv t

clean:
	$(LATEXMK) -C manbib.tex

distclean:
	$(LATEXMK) -C
