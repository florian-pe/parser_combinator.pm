#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use lib ".", "../";
use json_parser;

use Data::Dumper;
$Data::Dumper::Sortkeys=1;
$Data::Dumper::Indent = 1;

my $file = shift // exit;

local $/;
open my $fh, "<", $file;
$file = <$fh>;
close $fh;

my $json = json_parse($file);
say Dumper $json;

# use JSON::XS;
# say Dumper decode_json($file); # this should produce an identical output




