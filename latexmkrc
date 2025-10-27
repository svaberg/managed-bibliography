
my $ads_bib_file_stem = "adstex";  # Will create a bibliography named adstex.keys.bib

my $keys_file_extension = 'keys.lst';
my $tmp_tex_file_extension = 'keys.tex';
my $bib_file_extension = 'keys.bib';

push @generated_exts, $keys_file_extension;
push @generated_exts, $tmp_tex_file_extension;
push @generated_exts, $bib_file_extension;

add_hook('before_xlatex', 'run_adstex');

sub run_adstex {
    my $aux_file = "$$Pbase.aux";

    my $keys_file = "$$Pbase.$keys_file_extension";
    my $tmp_tex_file = "$$Pbase.$tmp_tex_file_extension";
    my $ads_bib_file = "$ads_bib_file_stem.$bib_file_extension";


    print "myextension: ******************************************************\n";
    print "myextension: * Forget bibliography management with pure ADS keys! *\n";
    print "myextension: ******************************************************\n";

    #
    # Ensure the generated bibliography file exists, as latexmk expects it
    #
    if (! -e $ads_bib_file) {
        print "myextension: Creating empty file $ads_bib_file (required by latexmk)...\n";
        open my $bf, '>', $ads_bib_file or die "Cannot create $ads_bib_file: $!";
        close $bf;
    }
    # If the keys file does not exist, create an empty one
    if (! -e $keys_file) {
        print "myextension: Creating empty file $keys_file (first run)...\n";
        open my $kf, '>', $keys_file or die "Cannot create $keys_file: $!";
        close $kf;
    }


    #
    # Read known citation keys from file
    #
    %known_keys = ();
    print "myextension: Reading known citation keys from $keys_file...\n";
    if (-e $keys_file) {
        open my $kfr, '<', $keys_file;
        while (my $line = <$kfr>) {
            chomp $line;
            $known_keys{$line} = 1 if $line ne '';
        }
        close $kfr;
        print "myextension: Read  ", scalar(keys %known_keys), " known citation keys from $keys_file.\n";
    }
    else {
        print "myextension: The file $keys_file does not exist (normal after cleaning).\n";
    }

    #
    # The aux file exists even on the first pass. We read two things from the file: 
    #  1) bibliography files used (not used here)
    #  2) current citation keys used in the document
    #
    my @user_bibs;
    open my $fh, '<', $aux_file;
    while (<$fh>) {
        if (/^\\bibdata\{([^}]*)\}/) {
            @user_bibs = map { /\.bib$/i ? $_ : "$_.bib" } grep /\S/, split /,/, $1;
            last;
        }
    }
    close $fh;
    print "myextension: Bibliography files used in document: ", join(", ", @user_bibs), "\n";

    
    
    my %keys;
    print "myextension: Reading current citation keys from $aux_file...\n";
    open my $fh, '<', $aux_file;
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
    print "myextension: Finished reading ", scalar(keys %keys), " current citation keys from $aux_file.\n";


    #
    # Compare current keys to known keys
    #
    print "myextension: Comparing current citation keys to known citation keys...\n";
    my $new_keys_found = 0;
    foreach my $key (keys %keys) {
        unless (exists $known_keys{$key}) {
            $new_keys_found = 1;
            last;;
        }
    }
    if (not $new_keys_found) {
        print "myextension: Only previously known citation keys found; finished.\n";
        return 0;
    }
    else {
        print "myextension: There are unprocessed citation keys.\n";
    }

    # 
    # Update known keys file
    #
    print "myextension: Writing updated known keys to $keys_file...\n";
    open my $kf, '>', $keys_file;
    print {$kf} join("\n", sort keys %keys), "\n";
    close $kf;
    print "myextension: Finished writing updated known keys to $keys_file.\n";

    #
    # Create temporary TeX file to run adstex on
    #
    print "myextension: Writing temporary TeX file $tmp_tex_file for adstex...\n";
    open my $tf, '>', $tmp_tex_file;
    print {$tf} "\\documentclass{article}\\begin{document}\n";
    if (%keys) {
        print {$tf} "\\cite{", join(',', sort keys %keys), "}\n";
    }
    print {$tf} "\\end{document}\n";
    close $tf;
    print "myextension: Finished writing temporary TeX file $tmp_tex_file for adstex.\n";

    #
    # Run adstex on the temporary TeX file
    #
    # The --other options: pass all user bibliography files except the managed one
    print "myextension: Running adstex on $tmp_tex_file to produce $ads_bib_file\n";
    my $other_opts = join '', map { qq{ --other "$_"} }
                grep { $_ ne $ads_bib_file && -e $_ } @user_bibs;
    my $cmd = "adstex \"$tmp_tex_file\" --no-update $other_opts --output $ads_bib_file";
    print "myextension: Running external command: $cmd\n";
    my $rc = system($cmd);
    print "myextension: Finished running adstex on $tmp_tex_file.\n";
    return ($rc == 0) ? 0 : 1;
}
