use strict;
use warnings;

use FindBin qw($Bin);
use File::Spec;
use Test::More;

my $script = File::Spec->catfile($Bin, '..', 'managed-bibliography.pl');
my $rv = do $script;
die $@ if $@;
die "could not load $script: $!" if !defined $rv;


{
    package TestHTTPClient;

    sub new {
        my ($class, @responses) = @_;
        return bless {
            responses => \@responses,
            urls => [],
            requests => [],
        }, $class;
    }

    sub post {
        my ($self, $url, $options) = @_;
        push @{$self->{urls}}, $url;
        push @{$self->{requests}}, $options;
        return shift @{$self->{responses}};
    }

    sub urls {
        my ($self) = @_;
        return @{$self->{urls}};
    }

    sub requests {
        my ($self) = @_;
        return @{$self->{requests}};
    }
}


sub capture_stderr {
    my ($code) = @_;
    my $output = '';
    open my $fh, '>', \$output or die "open scalar stderr: $!";
    local *STDERR = $fh;
    my @result = $code->();
    return (\@result, $output);
}


subtest 'successful bulk response returns fetched keys' => sub {
    my $http = TestHTTPClient->new({
        success => 1,
        content => '{"export":"@article{2001A&A...123..456A,\n}\n\n@article{2002Sci...295...82K,\n}\n"}',
    });

    my ($status, $content, $detail) = ManagedBibliography::fetch_ads_bibtex_entries(
        ['2001A&A...123..456A', '2002Sci...295...82K'],
        http_client => $http,
    );

    is($status, 'ok', 'success maps to ok');
    like($content, qr/\@article\{2001A&A\.\.\.123\.\.456A,/, 'bibtex body is returned');
    ok($detail->{'2001A&A...123..456A'}, 'first fetched key is returned');
    ok($detail->{'2002Sci...295...82K'}, 'second fetched key is returned');
    is(
        ($http->urls())[0],
        'https://api.adsabs.harvard.edu/v1/export/bibtex',
        'bulk export uses the ADS bulk endpoint',
    );
    like(
        ($http->requests())[0]{content},
        qr/"bibcode"\s*:\s*\["2001A&A\.\.\.123\.\.456A","2002Sci\.\.\.295\.\.\.82K"\]/,
        'bulk export sends bibcodes as JSON content',
    );
};


subtest 'partial bulk response returns only found keys' => sub {
    my $http = TestHTTPClient->new({
        success => 1,
        content => '{"export":"@article{2002Sci...295...82K,\n}\n"}',
    });

    my ($status, $content, $detail) = ManagedBibliography::fetch_ads_bibtex_entries(
        ['2002Sci...295...82K', 'missing'],
        http_client => $http,
    );

    is($status, 'ok', 'partial success still maps to ok');
    ok($detail->{'2002Sci...295...82K'}, 'returned key is present');
    ok(!$detail->{missing}, 'missing key is absent from returned key set');
    like($content, qr/\@article\{2002Sci\.\.\.295\.\.\.82K,/, 'returned export text is preserved');
};


subtest '401/403 responses return auth failure' => sub {
    for my $http_status (401, 403) {
        my $http = TestHTTPClient->new({
            success => 0,
            status => $http_status,
        });

        my ($status, $content, $detail) = ManagedBibliography::fetch_ads_bibtex_entries(
            ['auth-problem'],
            http_client => $http,
        );

        is($status, 'auth', "HTTP $http_status maps to auth");
        ok(!defined $content, "HTTP $http_status has no content");
        is($detail, $http_status, "HTTP $http_status detail is returned");
    }
};


subtest 'invalid JSON response returns error' => sub {
    my $http = TestHTTPClient->new({
        success => 1,
        content => 'not json',
    });

    my ($result, $stderr) = capture_stderr(
        sub {
            return ManagedBibliography::fetch_ads_bibtex_entries(
                ['broken'],
                http_client => $http,
            );
        }
    );
    my ($status, $content, $detail) = @{$result};

    is($status, 'error', 'invalid JSON maps to error');
    ok(!defined $content, 'invalid JSON has no content');
    ok(!defined $detail, 'invalid JSON has no detail');
    like($stderr, qr/invalid JSON/, 'invalid JSON warns clearly');
};


subtest 'missing Perl HTTPS support fails before ADS bulk export starts' => sub {
    my ($result, $stderr) = capture_stderr(
        sub {
            no warnings 'redefine';
            no warnings 'once';
            local *ManagedBibliography::perl_https_support_available = sub { return 0; };
            local *ManagedBibliography::format_ads_https_support_error_lines = sub {
                return (
                    'manbib: ADS lookups require Perl HTTPS support, but the active Perl cannot make HTTPS requests.',
                    'manbib: Hint: you may not be using the system Perl.',
                    'manbib: Aborting ADS work for this run.',
                );
            };
            local *ManagedBibliography::ads_http_client = sub {
                die 'ads_http_client should not be reached when HTTPS support is missing';
            };
            return ManagedBibliography::fetch_ads_bibtex_entries(['broken']);
        }
    );
    my ($status, $content, $detail) = @{$result};

    is($status, 'error', 'missing HTTPS support maps to error before bulk export starts');
    ok(!defined $content, 'missing HTTPS support has no export content');
    ok(!defined $detail, 'missing HTTPS support has no extra detail');
    like($stderr, qr/ADS lookups require Perl HTTPS support/, 'missing HTTPS support warns clearly');
    like($stderr, qr/you may not be using the system Perl/, 'missing HTTPS support suggests the non-system-Perl cause');
    like($stderr, qr/Aborting ADS work for this run/, 'missing HTTPS support says the run is being aborted');
};


subtest 'other failures return error' => sub {
    my $http = TestHTTPClient->new({
        success => 0,
        status => 599,
        reason => 'Internal Exception',
        content => 'SSL connect attempt failed',
    });

    my ($result, $stderr) = capture_stderr(
        sub {
            return ManagedBibliography::fetch_ads_bibtex_entries(
                ['broken'],
                http_client => $http,
            );
        }
    );
    my ($status, $content) = @{$result};

    is($status, 'error', 'unexpected failures map to error');
    ok(!defined $content, 'error response has no content');
    like($stderr, qr/status 599 \(Internal Exception\): SSL connect attempt failed/, 'unexpected failures warn with HTTP::Tiny detail');
    like($stderr, qr/manbib: Perl runtime:\nmanbib:   executable: /, 'unexpected failures log the active Perl runtime as a block');
    like($stderr, qr/manbib:   PERL5LIB: /, 'unexpected failures include PERL5LIB in the runtime block');
    like($stderr, qr/manbib: Perl \@INC:/, 'unexpected failures log the Perl library search path');
    like($stderr, qr/manbib: Perl module visibility:\nmanbib:   HTTP::Tiny=/, 'unexpected failures log module visibility as a block');
    like($stderr, qr/manbib:   IO::Socket::SSL=/, 'unexpected failures log SSL module visibility');
    unlike($stderr, qr/\(\@INC contains:/, 'module visibility omits redundant embedded @INC text');
};

done_testing;
