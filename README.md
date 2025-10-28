This Perl script uses NASA astronomy data service (ADS) citation keys and the `adstex` Python package so that you can forget about your bibliography management! For citation commands in your document that use ADS citation keys, i.e., commands like this `\cite{1958ZA.....46..108B}`, the script automatically fetches and caches the bibliography entries from the ADS database in a managed bibliography file (normally with extension `.adskeys.bib`).

Citations with keys that are not present in the ADS database can be added by providing one or more additional bibliography files, as is done in the source file for this document: `\bibliography{manbib.adskeys,custom}`.

The script is intended for integration with `latexmk`, which automates the build process for LaTeX documents.

## How it works

The Perl script `managed-bibliography.pl` reads bibliography information from the `.aux` file which is created by the LaTeX compiler during a build. The script builds a small `.keys.tex` file which contains all the citations in the `.tex` files that are part of the build. This file is passed to the Python `adstex` package, which updates the managed bibliography file when new ADS citation keys are found.

Keys that are no longer used in the document are not automatically removed from the managed bibliography file, but they can be purged by deleting the managed bibliography file and rebuilding the document. You can also use the `delete_on_full_clean` option to have the managed bibliography file deleted when running `latexmk -C`. (Note that depending on other settings, `latexmk` may keep or delete the `.bbl` file during a clean operation.)

An example of how to integrate the script with `latexmk` is provided in the `latexmkrc` file included in this repository.

## Test case

To build `manbib.tex` with `latexmk` run the following command in the terminal:

    latexmk -pdf -bibtex manbib.tex

This will create the file `manbib.pdf` along with the managed bibliography file `manbib.adskeys.bib`. You can clean up the generated files by running:

    latexmk -C manbib.tex
