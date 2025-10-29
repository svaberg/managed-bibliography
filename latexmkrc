#
# Settings for managed-bibliography.pl script
#
# To use this extension with latexmk, add the contents
# of this file to your latexmkrc file.
#
# By default the managed bibliography file is named the
# same as the main LaTeX basename. For document.tex it
# will be document.keys.bib. This default applies when
# $managed_bib_file is unset (or set to undef). You can
# set a different name here; useful if you want to share
# one managed bibliography file between multiple LaTeX
# documents in the same directory.
# $managed_bib_file = "adskeys.bib";
#
# Additional options to pass to adstex. Recommended:
#   --no-update  (do not update existing entries)
#   --no-backup  (do not create backup files)
# See the adstex documentation for more options.
$adstex_options = "--no-update --no-backup";
#
# Force deletion of the managed bibliography file on an
# 'extra full' clean (latexmk -C). Normally not needed
# and will slow the next build since the file must be
# recreated. Set:
#   0 = do not delete (recommended)
#   1 = delete on extra full clean
$delete_on_full_clean = 0;
#
# Extensions for the managed bibliography and citation
# keys LaTeX file. The default values are 
# 'adskeys.bib' and 'keys.tex'.
$bib_file_extension = 'adskeys.bib';
$keys_tex_file_extension = 'keys.tex';
#
# Add this to latexmkrc to load the script:
require './managed-bibliography.pl';
#
# End of settings for managed-bibliography.pl



# Separate configuration to build manbib.tex. Not part of
# the managed-bibliography.pl settings.
add_hook('before_xlatex', 'convert_readme');
sub convert_readme {
    return system("pandoc README.md -o README.tex");
}
