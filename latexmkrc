#
# Settings for the managed-bibliography.pl script
#
# To use this extension with latexmk, add the contents
# of this file to your latexmkrc file.
#
# By default the managed bibliography file is named
# after the main LaTeX basename. For document.tex it
# will be document.adskeys.bib. This applies when
# $managed_bib_file is unset (or set to undef). You
# can set a different name here, for example to share
# one managed bibliography file between multiple
# LaTeX documents in the same directory.
# $managed_bib_file = "adskeys.bib";
#
# ADS API token. By default the script looks for
# ADS_API_TOKEN, ADS_DEV_KEY, ~/.ads/token, and
# ~/.ads/dev_key. You can override that here if
# needed. That is not recommended for project
# files that may be committed.
# $ads_api_token = '...';
#
# Force deletion of the managed bibliography file on
# a full clean (latexmk -C). Normally not needed.
# It will slow the next build because the file
# must be recreated. It also forces a fresh ADS
# lookup on the next build, which can replace
# stale cached entries. Set:
#   0 = do not delete
#   1 = delete on full clean
$delete_on_full_clean = 1;
#
# Extension for the managed bibliography file. The
# default value is 'adskeys.bib'.
$bib_file_extension = 'adskeys.bib';
#
# Add this to latexmkrc to load the script:
require './managed-bibliography.pl';
#
# End of settings for managed-bibliography.pl
