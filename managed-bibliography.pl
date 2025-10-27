# managed-bibliography.pl
#
# Latexmk extension for maintaining a managed bibliography using adstex.
#
# This script hooks into latexmk’s build process (before_xlatex) to:
#   - Parse the .aux file for citation keys and bibliography files
#   - Maintain a separate managed .bib file (e.g. adstex.keys.bib)
#   - Keep a cache of all seen citation keys in a simple LaTeX file (keys.tex)
#   - Regenerate the managed bibliography automatically via adstex
#
# To use:
#   1. Place this file in your project directory.
#   2. In latexmkrc, set any desired defaults, then:
#          require './managed-bibliography.pl';
#
# You can also load it ad-hoc:
#          latexmk -r managed-bibliography.pl -pdf document.tex
#
# Configuration variables normally set in latexmkrc:
#   $ads_bib_file_stem         # name stem for the managed keys.bib file (default: adstex)
#   $adstex_options            # options passed to adstex (default: --no-update --no-backup)
#   $bib_file_extension        # suffix for managed .bib file (default: keys.bib)
#   $keys_tex_file_extension   # suffix for cached keys file (default: keys.tex)
#
# See: https://github.com/svaberg/managed-bibliography


if ($delete_on_full_clean) {
    add_hook('cleanup_extra_full', 'delete_managed_bibliography');
}

push @generated_exts, $keys_tex_file_extension;

add_hook('before_xlatex', 'manage_bibliography');


sub manage_bibliography {

    print "myextension: ******************************************************\n";
    print "myextension: * Forget bibliography management with pure ADS keys! *\n";
    print "myextension: ******************************************************\n";

    my $aux_file = "$$Pbase.aux";
    my $keys_tex_file = "$$Pbase.$keys_tex_file_extension";
    if (!defined $ads_bib_file_stem) {
        $ads_bib_file_stem = $$Pbase;
    }
    my $ads_bib_file = "$ads_bib_file_stem.$bib_file_extension";


    # Ensure the generated bibliography file exists, as latexmk expects it
    if (! -e $ads_bib_file) {
        print "myextension: Creating empty file $ads_bib_file (first use).\n";
        open my $bf, '>', $ads_bib_file or die "Cannot create $ads_bib_file: $!";
        close $bf;
    }

    # Read bibliography files and current citation keys from the .aux file.
    my @bibtex_files = discover_bibtex_files($aux_file);
    if (not @bibtex_files) {
        print "myextension: No bibliography files found in $aux_file; nothing to do.\n";
        return 0;
    }
    # If the managed bibliography file is not among them we can end here.
    if (! grep { $_ eq $ads_bib_file } @bibtex_files) {
        print "myextension: Managed bibliography file $ads_bib_file not in use; nothing to do.\n";
        return 0;
    }
    # Read current citation keys from the .aux file
    my %keys = parse_keys($aux_file);

    # Read cached citation keys from the citation keys LaTeX file
    my %cached_keys = read_cached_keys($keys_tex_file);
    print "myextension: Read ", scalar(keys %cached_keys), " cached citation keys from $keys_tex_file.\n";

    #
    # Compare current keys to cached keys
    #    
    my %all_keys = (%cached_keys, %keys);  # Merged set
    my @new_keys   = grep { !$cached_keys{$_} } keys %keys;  # Keys not in cache
    if (!@new_keys) {
        print "myextension: No uncached citation keys found; finished.\n";
        return 0;
    }
    print "myextension: Found ", scalar(@new_keys), " new, uncached citation keys.\n";

    # Write citation keys LaTeX file for adstex
    write_cached_keys($keys_tex_file, %all_keys);

    #
    # Run adstex on the citation keys LaTeX file
    #
    print "myextension: Running adstex on $keys_tex_file to generate $ads_bib_file\n";
    # The --other options: pass all user bibliography files except the managed one
   my @user_bibtex_files = grep { $_ ne $ads_bib_file && -e $_ } @bibtex_files;
    print "myextension: User bibliography files for adstex: @user_bibtex_files\n";

    my $other_part = '';
    if (@user_bibtex_files) {
        print "myextension: Constructing other_part for adstex with user bibliography files.\n";
        my $files = join ' ', map { qq{"$_"} } @user_bibtex_files;
        $other_part = "--other $files";
    }
    print "myextension: Constructed other_part for adstex: $other_part\n";
    my $cmd = "adstex \"$keys_tex_file\" $adstex_options $other_part --output \"$ads_bib_file\"";
    print "myextension: Running external command:\n";
    print "myextension> $cmd\n";
    my $rc = system($cmd);
    print "myextension: Finished running adstex on $keys_tex_file.\n";
    return ($rc == 0) ? 0 : 1;
}


sub discover_bibtex_files {
    # Discover bibliography files from the .aux file
    # We look for the command \bibdata{file1,file2,...}
    # Returns a list of bibliography files (with .bib extension)
    # The content of \bibdata is determined by the \bibliography{} command(s) in the LaTeX source.
    my ($aux_file) = @_;

    my @bibtex_files;

    open my $fh, '<', $aux_file;
    binmode($fh, ':encoding(UTF-8)');
    while (<$fh>) {
        if (/^\\bibdata\{([^}]*)\}/) {
            @bibtex_files
         = map { /\.bib$/i ? $_ : "$_.bib" } grep /\S/, split /,/, $1;
            last;
        }
    }
    close $fh;

    return @bibtex_files;
}


sub parse_keys {
    # Parse citation keys from the .aux file
    # Supports both BibTeX and biblatex citation formats
    # Returns a hash of citation keys
    my ($aux_file) = @_;
    print "myextension: Reading citation keys from $aux_file...\n";

    my %keys;
    open my $fh, '<', $aux_file;
    binmode($fh, ':encoding(UTF-8)');
    while (my $line = <$fh>) {
        # BibTeX form:   \citation{a,b,c}
        if ($line =~ /^\\citation\{([^}]*)\}/) {
            $keys{$_} = 1 for grep { $_ ne '' } split /,/, $1;
        }
        # biblatex form: \abx@aux@cite{<ctx>}{key}
        if ($line =~ /^\\abx\@aux\@cite\{[^}]*\}\{([^}]*)\}/) {
            $keys{$1} = 1;
        }
    }
    close $fh;
    print "myextension: Finished reading ", scalar(keys %keys), " citation keys from $aux_file.\n";

    return %keys;
}


sub read_cached_keys {
    # Read cached citation keys from the citation keys LaTeX file
    # The file is created if it does not exist
    my ($keys_tex_file) = @_;

    my %keys;

    if (! -e $keys_tex_file) {
        print "myextension: Creating empty file $keys_tex_file (first use).\n";
        open my $kf, '>', $keys_tex_file or die "myextension: Cannot create $keys_tex_file: $!";
        close $kf;
        return %keys;
    }

    print "myextension: Reading cached citation keys from $keys_tex_file...\n";
    open my $fh, '<', $keys_tex_file or return %keys;
    binmode($fh, ':encoding(UTF-8)');
    while (<$fh>) {
        next if /^\s*%/;  # skip comments
        while (/\\cite\{([^}]*)\}/g) {
            $keys{$1} = 1 if length $1;
        }
    }
    close $fh;
    return %keys;
}


sub write_cached_keys {
    # Create citation keys LaTeX file to run adstex on
    # The citation keys are written as \cite{key} commands, each on a separate line
    my ($keys_tex_file, %keys) = @_;
    print "myextension: Writing ", scalar(keys %keys), " citation keys to LaTeX file $keys_tex_file...\n";
    open my $tf, '>', $keys_tex_file;
    binmode($tf, ':encoding(UTF-8)');

    print {$tf} "\\documentclass{article}\n";
    print {$tf} "\\begin{document}\n";
    print {$tf} "Citation keys file generated by latexmk extension for adstex.\n";
    print {$tf} "There are ", scalar(keys %keys), " citation keys in total.\n";
    print {$tf} "\n";
    for my $k (sort keys %keys) {
        next unless length $k;
        print {$tf} "\\cite{$k}\n";
    }
    print {$tf} "\n";
    print {$tf} "\\end{document}\n";
    close $tf or die "close $keys_tex_file: $!";
    print "myextension: Finished writing citation keys LaTeX file $keys_tex_file.\n";
}


sub delete_managed_bibliography {
    if (!defined $ads_bib_file_stem) {
        $ads_bib_file_stem = $$Pbase;
    }
    my $ads_bib_file = "$ads_bib_file_stem.$bib_file_extension";

    if (-e $ads_bib_file) {
        print "myextension: Removing generated file $ads_bib_file during clean.\n";
        unlink $ads_bib_file or warn "myextension: Could not remove $ads_bib_file: $!";
    }
    return 0;
}
