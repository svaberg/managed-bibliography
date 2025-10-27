
my $ads_bib_file_stem = "adstex";  # Will create a bibliography named adstex.keys.bib

my $keys_file_extension = 'keys.lst';
my $tmp_tex_file_extension = 'keys.tex';
my $bib_file_extension = 'keys.bib';

push @generated_exts, $keys_file_extension;
push @generated_exts, $tmp_tex_file_extension;
push @generated_exts, $bib_file_extension;

add_hook('before_xlatex', 'run_adstex');


sub run_adstex {

    print "myextension: ******************************************************\n";
    print "myextension: * Forget bibliography management with pure ADS keys! *\n";
    print "myextension: ******************************************************\n";

    my $aux_file = "$$Pbase.aux";

    my $keys_file = "$$Pbase.$keys_file_extension";
    my $tmp_tex_file = "$$Pbase.$tmp_tex_file_extension";
    my $ads_bib_file = "$ads_bib_file_stem.$bib_file_extension";


    # Ensure the generated bibliography file exists, as latexmk expects it
    if (! -e $ads_bib_file) {
        print "myextension: Creating empty file $ads_bib_file (first use)...\n";
        open my $bf, '>', $ads_bib_file or die "Cannot create $ads_bib_file: $!";
        close $bf;
    }

    #
    # Read bibliography files and current citation keys from the .aux file.
    #
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


    # Read known citation keys from the keys file
    my %known_keys = read_known_keys($keys_file);


    #
    # Compare current keys to known keys
    #    
    my %all_keys = (%known_keys, %keys);  # Merged set
    my @new_keys   = grep { !$known_keys{$_} } keys %keys;  # New, unseen keys only
    if (!@new_keys) {
        print "myextension: No new citation keys found; finished.\n";
        return 0;
    }
    print "myextension: Found ", scalar(@new_keys), " new citation keys.\n";

    # Update known keys file
    open my $kf, '>', $keys_file or die "open $keys_file: $!";
    binmode($kf, ':encoding(UTF-8)');
    print {$kf} join("\n", sort keys %all_keys), "\n";
    close $kf;
    print "myextension: Updated $keys_file with ", scalar(keys %all_keys), " total keys.\n";

    # Write temporary LaTeX file for adstex
    write_tmp_tex_file($tmp_tex_file, %all_keys);

    #
    # Run adstex on the temporary LaTeX file
    #
    print "myextension: Running adstex on $tmp_tex_file to produce $ads_bib_file\n";
    # The --other options: pass all user bibliography files except the managed one
    my $user_bibtex_files = join '', map { qq{ "$_"} }
        grep { $_ ne $ads_bib_file && -e $_ } @bibtex_files;
    my $cmd = "adstex \"$tmp_tex_file\" --no-update --other $user_bibtex_files --output $ads_bib_file";
    print "myextension: Running external command: $cmd\n";
    my $rc = system($cmd);
    print "myextension: Finished running adstex on $tmp_tex_file.\n";
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
    print "myextension: Reading current citation keys from $aux_file...\n";

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
    print "myextension: Finished reading ", scalar(keys %keys), " current citation keys from $aux_file.\n";

    return %keys;
}


sub read_known_keys {
    # Read known citation keys from the keys file
    # The file is created if it does not exist
    my ($keys_file) = @_;

    my %known_keys; 

    # If the keys file does not exist, create an empty one
    if (! -e $keys_file) {
        print "myextension: Creating empty file $keys_file (first use)...\n";
        open my $kf, '>', $keys_file or die "myextension: Cannot create $keys_file: $!";
        close $kf;
        return %known_keys;
    }

    print "myextension: Reading known citation keys from $keys_file...\n";
    if (-e $keys_file) {
        open my $kfr, '<', $keys_file;
        binmode($kfr, ':encoding(UTF-8)');
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
    return %known_keys;
}

sub write_tmp_tex_file {
    my ($tmp_tex_file, %all_keys) = @_;
    #
    # Create temporary LaTeX file to run adstex on
    #
    print "myextension: Writing temporary LaTeX file $tmp_tex_file for adstex...\n";
    open my $tf, '>', $tmp_tex_file;
    binmode($tf, ':encoding(UTF-8)');
    print {$tf} "\\documentclass{article}\\begin{document}\n";
    if (%all_keys) {
        print {$tf} "\\cite{", join(',', sort keys %all_keys), "}\n";
    }
    print {$tf} "\\end{document}\n";
    close $tf;
    print "myextension: Finished writing temporary LaTeX file $tmp_tex_file for adstex.\n";
}