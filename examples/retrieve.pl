#!/usr/bin/env perl

use strict;
use warnings;

die "Usage: perl retrieve.pl <paste_ID_or_URI>\n"
    unless @ARGV;

my $Paste = shift;

use lib '../lib';
use WWW::PastebinCa::Retrieve;

my $paster = WWW::PastebinCa::Retrieve->new;

my $content_ref = $paster->retrieve( $Paste )
    or die "Failed to retrieve paste $Paste: " . $paster->error;

printf "Posted on %s, titled %s and aged %s\n\n%s\n",
         @$content_ref{ qw(post_date  name  age  content ) };