
# Settings for managed-bibliography.pl script
#
# To use this extension with latexmk, add the contents
# of this file to your latexmkrc file.

# By default the managed bibliography file is called named 
# the same as the main LaTeX file base name, e.g.,
# for document.tex it will be document.keys.bib. This default
# behaviour occurs when $managed_bib_file is unset (or set 
# to undef). You can set a different name  
# here; this is useful if you want to share the same 
# managed bibliography file between multiple LaTeX 
# documents in the same directory.
$managed_bib_file = "adskeys.bib";

# Additional options to pass to adstex. The recommended 
# defaults are:
# --no-update: do not update existing entries 
#              in the managed bibliography file
# --no-backup: do not create backup files of the 
#              managed bibliography file
# For more options see the adstex documentation.
$adstex_options = "--no-update --no-backup";  

# Force the deletion of the managed bibliography file 
# on an 'extra full' clean (latexmk -C) operation. 
# This should normally not be required and will slow down 
# the build after an extra full clean, since the managed 
# bibliography file will have to be recreated from scratch.
# Set to:
#   0 = do not delete (recommended)
#   1 = delete the managed bibliography file on full clean
$delete_on_full_clean = 1;

# Extensions for the managed bibliography file and citation 
# keys LaTeX file The recommended defaults are 'keys.bib' 
# and 'keys.tex'. Note that 
$bib_file_extension = 'adskeys.bib';
$keys_tex_file_extension = 'keys.tex';

# Add this to latexmkrc to loads the script
require './managed-bibliography.pl';