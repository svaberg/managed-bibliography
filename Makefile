.PHONY: all test clean distclean

LATEXMK ?= latexmk
PROVE ?= prove
ROOT = manbib.tex
ROOT_BASE = $(basename $(ROOT))
MARKDOWN_CACHE_DIR = _markdown_$(ROOT_BASE)
MARKDOWN_LUABRIDGE = $(ROOT_BASE).luabridge.lua

all: manbib.pdf

manbib.pdf: README.md $(ROOT) managed-bibliography.pl latexmkrc
	$(LATEXMK) -lualatex -bibtex $(ROOT)

test:
	$(PROVE) -lv t

clean:
	$(LATEXMK) -c $(ROOT)
	rm -rf $(MARKDOWN_CACHE_DIR) $(MARKDOWN_LUABRIDGE)

distclean:
	$(LATEXMK) -C
	rm -rf $(MARKDOWN_CACHE_DIR) $(MARKDOWN_LUABRIDGE)
