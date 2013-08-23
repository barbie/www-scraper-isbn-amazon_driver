#!/usr/bin/perl -w
use strict;

use Test::More tests => 41;
use WWW::Scraper::ISBN;
use Data::Dumper;

###########################################################

my $DRIVER          = 'AmazonUS';
my $CHECK_DOMAIN    = 'www.google.com';

my %tests = (
    '0201795264' => [
        [ 'is',     'isbn',         '9780201795264'                 ],
        [ 'like',   'isbn10',       qr!020179526!                   ],  # Amazon have a broken ISBN-10 field!
        [ 'is',     'isbn13',       '9780201795264'                 ],
        [ 'is',     'ean13',        '9780201795264'                 ],
        [ 'like',   'title',        qr!Perl Medic!                  ],
        [ 'like',   'author',       qr!Peter.*Scott!                ],
        [ 'is',     'publisher',    'Addison-Wesley Professional'   ],
        [ 'like',   'pubdate',      qr/2004$/                       ],  # this date fluctuates throughout Mar/Apr 2004!
        [ 'is',     'binding',      'Paperback'                     ],
        [ 'is',     'pages',        336                             ],
        [ 'is',     'width',        177                             ],
        [ 'is',     'height',       233                             ],
        [ 'is',     'depth',        20                              ],
        [ 'is',     'weight',       544                             ],
        [ 'like',   'image_link',   qr!^http://(www\.|[-\w]+\.images-)amazon\.com/(gp/product/images|images/[-\w/.,]+\.jpg)! ],
        [ 'like',   'thumb_link',   qr!^http://(www\.|[-\w]+\.images-)amazon\.com/(gp/product/images|images/[-\w/.,]+\.jpg)! ],
        [ 'like',   'description',  qr|This book is about taking over Perl code| ],
        [ 'like',   'book_link',    qr!^http://www.amazon.com/(Perl-Medic|.*?field-keywords=(0201795264|9780201795264))! ]
    ],
    '9780672320675' => [
        [ 'is',     'isbn',         '9780672320675'                 ],
        [ 'like',   'isbn10',       qr!067232067!                   ],  # Amazon have a broken ISBN-10 field!
        [ 'is',     'isbn13',       '9780672320675'                 ],
        [ 'is',     'ean13',        '9780672320675'                 ],
        [ 'is',     'author',       'Clinton Pierce'                ],
        [ 'like',   'title',        qr!Perl Developer.*?Dictionary! ],
        [ 'like',   'publisher',    qr/^Sams/                       ],  # publisher name changes!
        [ 'like',   'pubdate',      qr/2001$/                       ],  # this dates fluctuates throughout Jul 2001!
        [ 'is',     'binding',      'Paperback'                     ],
        [ 'is',     'pages',        640                             ],
        [ 'is',     'width',        187                             ],
        [ 'is',     'height',       231                             ],
        [ 'is',     'depth',        35                              ],
        [ 'is',     'weight',       1043                            ],
        [ 'like',   'image_link',   qr!^http://(www\.|[-\w]+\.images-)amazon\.com/(gp/product/images|images/[-\w/.,]+\.jpg)! ],
        [ 'like',   'thumb_link',   qr!^http://(www\.|[-\w]+\.images-)amazon\.com/(gp/product/images|images/[-\w/.,]+\.jpg)! ],
        [ 'like',   'description',  qr|Perl Developer's Dictionary is a complete|                            ],
        [ 'like',   'book_link',    qr!http://www.amazon.com/(Perl-Developers-Dictionary|.*?field-keywords=(0672320673|9780672320675))! ]
    ],
);

my $tests = 0;
for my $isbn (keys %tests) { $tests += scalar( @{ $tests{$isbn} } ) + 2}


###########################################################

my $scraper = WWW::Scraper::ISBN->new();
isa_ok($scraper,'WWW::Scraper::ISBN');

SKIP: {
	skip "Can't see a network connection", $tests   if(pingtest($CHECK_DOMAIN));

	$scraper->drivers($DRIVER);

    for my $isbn (keys %tests) {
        my $record = $scraper->search($isbn);
        my $error  = $record->error || '';

        SKIP: {
            skip "Website unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /website appears to be unavailable/);
            skip "Book unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /Failed to find that book/ || !$record->found);

            unless($record->found) {
                diag($record->error);
            }

            is($record->found,1);
            is($record->found_in,$DRIVER);

            my $fail = 0;
            my $book = $record->book;
            for my $test (@{ $tests{$isbn} }) {
                if($test->[0] eq 'ok')          { ok(       $book->{$test->[1]},             ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'is')       { is(       $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'isnt')     { isnt(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'like')     { like(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'unlike')   { unlike(   $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); }

                $fail = 1   unless(defined $book->{$test->[1]} || ($test->[0] ne 'ok' && !defined $test->[2]));
            }

            diag("book=[".Dumper($book)."]")    if($fail);
        }
    }
}

###########################################################

# crude, but it'll hopefully do ;)
sub pingtest {
    my $domain = shift or return 0;
    my $cmd =   $^O =~ /solaris/i                           ? "ping -s $domain 56 1" :
                $^O =~ /dos|os2|mswin32|netware|cygwin/i    ? "ping -n 1 $domain "
                                                            : "ping -c 1 $domain >/dev/null 2>&1";

    eval { system($cmd) }; 
    if($@) {                # can't find ping, or wrong arguments?
        diag();
        return 1;
    }

    my $retcode = $? >> 8;  # ping returns 1 if unable to connect
    return $retcode;
}
