
# Settings for managed-bibliography.pl extension for latexmk
# To use this extension, add the following lines to your latexmkrc file:
#
# By default the managed bibligraphy file is called adstex.keys.bib
# Set a different name stem of managed bibliography here,
# or leave undefined (by commenting out) to use the main LaTeX file base name.
$ads_bib_file_stem = "adstex";  
#
# Additional options to pass to adstex. The defaults are
# --no-update: do not update existing entries in the managed bibliography file
# --no-backup: do not create backup files of the managed bibliography file
# For more options see the adstex documentation.
$adstex_options = "--no-update --no-backup";  
#
# Force the deletion of the managed  bibliography file on an 
# 'extra full' clean (latexmk -C) operation.
# 0 = do not delete (the default)
# 1 = delete the managed bibliography file on full clean
$delete_on_full_clean = 1;
#
# Extensions for the managed bibliography file and citation keys LaTeX file
# The defaults are 'keys.bib' and 'keys.tex'
$bib_file_extension = 'keys.bib';
$keys_tex_file_extension = 'keys.tex';
#
# This actually loads the extension
require './managed-bibliography.pl';