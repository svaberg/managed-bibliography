# Managed bibliography with ADS keys

Forget about bibliography management with pure NASA ADS keys!

This drop-in Perl script uses citation keys from the [NASA astronomy data service (ADS)](https://ui.adsabs.harvard.edu/) so that you can forget about your bibliography management. For citation commands in your document that use ADS keys, such as `\cite{1958ZA.....46..108B}`, the script automatically fetches and caches the corresponding bibliography entries in a managed bibliography file, normally with extension `.adskeys.bib`.

Citations with keys that are not present in the ADS database can be added by providing one or more additional bibliography files, as in `\bibliography{paper.adskeys,custom}`.

The script is intended for integration with [Latexmk](https://ctan.org/pkg/latexmk/), which automates the build process for LaTeX documents.

## How to use

Copy [`managed-bibliography.pl`](./managed-bibliography.pl) into your document directory. Then copy the [`latexmkrc`](./latexmkrc) file as well, or merge the its content with your preexisting `latexmkrc` file.

Add the managed bibliography file to your `\bibliography{...}` command. By default, a document `paper.tex` uses `paper.adskeys.bib`, so a typical setup looks like `\bibliography{paper.adskeys,custom}`. If you set `$managed_bib_file` to another filename, use that basename instead.

Provide an ADS [API token](https://ui.adsabs.harvard.edu/help/api/) through `ADS_API_TOKEN`, `ADS_DEV_KEY`, `$HOME/.ads/token`, or `$HOME/.ads/dev_key`. Avoid putting tokens directly in a committed `latexmkrc` unless you really need to.

The script uses `HTTP::Tiny` and `JSON::PP`. Perl 5.14 or later is a sensible baseline. Then build as usual with `latexmk`. On the first run the managed bibliography file is created automatically.

## How it works

During a build, the script reads the `.aux` file to discover which bibliography files are in use and which citation keys were requested. It compares those keys with the managed bibliography file and any user-supplied `.bib` files already listed in `\bibliography{...}`.

Keys that are still unresolved are sent to ADS. The script first asks ADS to canonicalize identifiers, then exports the matching BibTeX entries in bulk, rewrites the exported entry keys back to the keys cited in the document, and stores the results in the managed bibliography file.

If ADS does not return an entry, the key is left unresolved and LaTeX/BibTeX behaves as it normally would for a missing citation.

By default, `latexmk -C` also removes the managed bibliography file. The next build then performs a fresh ADS lookup, which can refresh stale cached entries.

## Test case

To build [`manbib.tex`](./manbib.tex) with Latexmk, run:

    latexmk -pdf -bibtex manbib.tex

This creates [`manbib.pdf`](./manbib.pdf) together with the managed bibliography file [`manbib.adskeys.bib`](./manbib.adskeys.bib). To clean up the generated files, run:

    latexmk -C manbib.tex
