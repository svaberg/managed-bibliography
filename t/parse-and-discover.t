use strict;
use warnings;

use FindBin qw($Bin);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

my $script = File::Spec->catfile($Bin, '..', 'managed-bibliography.pl');
my $rv = do $script;
die $@ if $@;
die "could not load $script: $!" if !defined $rv;


sub write_file {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die "open $path: $!";
    print {$fh} $content;
    close $fh or die "close $path: $!";
}


sub capture_stdout {
    my ($code) = @_;
    my $output = '';
    open my $fh, '>', \$output or die "open scalar stdout: $!";
    local *STDOUT = $fh;
    my @result = $code->();
    return (\@result, $output);
}


my $tmpdir = tempdir(CLEANUP => 1);
my $aux_file = File::Spec->catfile($tmpdir, 'paper.aux');
my $bib_file = File::Spec->catfile($tmpdir, 'custom.bib');

write_file(
    $aux_file,
    <<'EOF'
\relax
\bibdata{paper.adskeys,custom,extra.bib}
\citation{alpha,beta}
\abx@aux@cite{0}{gamma}
EOF
);

write_file(
    $bib_file,
    <<'EOF'
@comment{ignored}
@string{ignored = "value"}
@preamble{"ignored"}

@article{local-one,
  title = {One},
}

@book{local-two,
  title = {Two},
}
EOF
);

is_deeply(
    [ManagedBibliography::discover_bibtex_files($aux_file)],
    [qw(paper.adskeys.bib custom.bib extra.bib)],
    'discover_bibtex_files reads bibdata entries',
);

{
    my ($result) = capture_stdout(sub { return ManagedBibliography::parse_keys($aux_file) });
    my %keys = @{$result};
    is_deeply(
        [sort keys %keys],
        [qw(alpha beta gamma)],
        'parse_keys reads BibTeX and biblatex citation keys',
    );
}

{
    my ($result) = capture_stdout(sub { return ManagedBibliography::read_bibliography_keys($bib_file) });
    my %keys = @{$result};
    is_deeply(
        [sort keys %keys],
        [qw(local-one local-two)],
        'read_bibliography_keys ignores comment-like BibTeX records',
    );
}

done_testing;
