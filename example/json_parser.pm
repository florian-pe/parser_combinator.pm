package json_parser;
use strict;
use warnings;
use Carp;
use parser_combinator;

sub import {
    no strict 'refs';
    my $caller = caller;
    *{"$caller\::json_parse"} = \&{"json_parser::json_parse"};
}

my $json_number =  capture(seq(
    opt(char("-")),
    alt(
        char("0"),
        seq(
            regex(qr/[1-9]/),
            star(
                regex(qr/[0-9]/),
            ),
        ),
    ),
    opt(
        seq(
            char("."),
            plus(regex(qr/[0-9]/))
        ),
    ),
    opt(
        seq(
            regex(qr/[eE]/),
            opt(
                regex(qr/[+-]/)
            ),
            plus(
                regex(qr/[0-9]/),
            ),
        ),
    ),
));

my $json_string = seq(
    char('"'),
    capture(
        star(
            alt(
                regex(qr/[^"\\]/),
                alt(
                    seq(
                        char("\\"),
                        regex(qr|["\\/bfnrt]|),
                    ),
                    seq(
                        string("\\u"),
                        exact(
                            4,
                            regex(qr/[0-9a-fA-F]/),
                        )
                    ),
                ),
            ),
        ),
    ),
    char('"'),
);

my $json_array = seq(
    char("["),
    ws_star(),
    opt(
        seq(
            rule("value"),
            ws_star(),
            star(
                seq(
                    char(","),
                    ws_star,
                    rule("value"),
                    ws_star,
                ),
            ),
        )
    ),
    char("]"),
);

my $json_pair = seq( rule("string"), ws_star(), char(":"), ws_star(), rule("value") );

my $json_object = seq(
    char("{"),
    ws_star(),
    opt(
        seq(
            rule("pair"),
            ws_star(),
            star(
                seq(
                    char(","),
                    ws_star,
                    rule("pair"),
                    ws_star,
                ),
            ),
        )
    ),
    char("}"),
);
 
my $json_parser = parser(

    top => [
        seq( SOS(), ws_star(), rule("value"), ws_star(), EOS() ),
        sub { my $match = shift; $match->{cap}[0] }
    ],

    value   => [
        alt(
            rule("true"),
            rule("false"),
            rule("null"),
            rule("number"),
            rule("string"),
            rule("array"),
            rule("object"),
        ),
        sub { my $match = shift; $match->{cap}[0] }
    ],

    true    => [ string("true"),  sub { "true" } ],
    false   => [ string("false"), sub { "false" } ],
#     null    => [ string("null"),  sub { "null" } ],
#     number  => [ $json_number,    sub { my $match = shift; $match->{cap}[0] } ],
#     string  => [ $json_string,    sub { my $match = shift; $match->{cap}[0] } ],


    # with this modification, the Data::Dumper output is identical to that of JSON::XS
    null    => [ string("null"),  sub { undef } ],
    number  => [ $json_number,    sub { my $match = shift; 0+$match->{cap}[0] } ],
    string  => [ $json_string,
        sub {
            my $match = shift; 
            $match->{cap}[0]
            =~ s/\\b/\b/gr
            =~ s/\\f/\f/gr
            =~ s/\\n/\n/gr
            =~ s/\\r/\r/gr
            =~ s/\\t/\t/gr
        }
    ],

    pair    => [ $json_pair,  sub { my $match = shift; $match->{cap} } ],
    array   => [ $json_array, sub { my $match = shift; $match->{cap} } ],

    object  => [ $json_object, sub {
            my $match = shift;
            return { map { $_->@* } $match->{cap}->@* };
        }
    ],
);

sub json_parse {
    my $string = shift // croak "json_parse(): undefined argument";
    $json_parser->($string);
}




1;

