This script uses NASA ADS citation keys with `adstex` so that you can
forget about your bibliography management! The extension fetches and
caches the bibliography entries from the NASA ADS database
automatically. The extension creates and manages a bibliography file
named `adstex.keys.bib` in the working directory.

Custom citations with keys not in the ADS database can be added by
providing one or more additional bibliography files, as is done in the
source file for this document.

## How it works {#how-it-works .unnumbered}

The `latexmkrc` file has been extended with a custom Perl script that
runs `adstex` automatically as part of the build process. The script
scans the LaTeX source file for citation keys, checks which keys are
already known (cached) in the local bibliography file, and fetches any
missing entries from the NASA ADS database using `adstex`. The fetched
entries are then added to the managed bibliography file, which is used
during the LaTeX compilation. During the process the extension makes use
a temporary TeX file `.keys.txt` which is built from itself and the
`.aux` file and consumed by `adstex`. After a deep clean (`latexmk -C`),
the extension builds everything in 3--4 passes which is what `latexmk`
normally does anyway.

Keys that are no longer used in the document are not automatically
removed from the managed bibliography file, but they can be removed
manually by deleting the `adstex.keys.bib` file and rebuilding the
document.
