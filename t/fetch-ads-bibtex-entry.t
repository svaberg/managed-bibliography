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


subtest 'other failures return error' => sub {
    my $http = TestHTTPClient->new({
        success => 0,
        status => 500,
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
    like($stderr, qr/status 500/, 'unexpected failures warn');
};

done_testing;
