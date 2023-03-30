package parser_combinator;
use strict;
use warnings;
use v5.10;
use Carp;

use Exporter 'import';
our @EXPORT = qw(
    SOS EOS
    any char string regex
    ws_plus ws_star
    alt seq opt star plus exact min_max
    capture
    rule
    parser
);

sub SOS {
    croak "SOS() doesn't take arguments" if @_;

    sub {
        my ($rules, $input, $pos) = @_;

        if ($pos == 0) {
            return { pos => $pos }
        }
        else {
            return { pos => undef }
        }
    }
}

sub EOS {
    croak "EOS() doesn't take arguments" if @_;

    sub {
        my ($rules, $input, $pos) = @_;

        if ($pos == length $$input) {
            return { pos => $pos }
        }
        else {
            return { pos => undef }
        }
    }
}

sub any {
    my $rules = shift;
    croak "any() doesn't take arguments" if @_;

    sub {
        my ($rules, $input, $pos) = @_;

        if ($pos >= length $$input) {
            return { pos => undef }
        }
        else {
            return { pos => $pos + 1 }
        }
    }
}

sub char {
    my $char = shift // croak "char() undefined argument";
    croak "char() take exactly 1 argument" if @_;

    sub {
        my ($rules, $input, $pos) = @_;

        if ($pos >= length $$input) {
            return { pos => undef }
        }
        elsif (substr($$input, $pos, 1) eq $char) {
            return { pos => $pos + 1 }
        }
        else {
            return { pos => undef }
        }
    }
}

sub string {
    my $string = shift // croak "string() undefined argument";
    croak "string() take exactly 1 argument" if @_;

    sub {
        my ($rules, $input, $pos) = @_;

        if ($pos >= length $$input) {
            return { pos => undef }
        }
        elsif (substr($$input, $pos, length $string) eq $string) {
            return { pos => $pos + length $string }
        }
        else {
            return { pos => undef }
        }
    }
}


sub ws_plus {
    croak "ws_plus() doesn't take arguments" if @_;

    sub {
        my ($rules, $input, $pos) = @_;

        if (substr($$input, $pos) =~ /^\s+/) {
            return { pos => $pos + length $& }
        }
        else {
            return { pos => undef }
        }
    }
}

sub ws_star {
    croak "ws_star() doesn't take arguments" if @_;

    sub {
        my ($rules, $input, $pos) = @_;

        if (substr($$input, $pos) =~ /^\s*/) {
            return { pos => $pos + length $& }
        }
        else {
            return { pos => undef }
        }
    }
}

sub regex {
    my $regex = shift // croak "regex() undefined argument";
    croak "regex() take exactly 1 argument" if @_;

    $regex = qr/^$regex/;

    sub {
        my ($rules, $input, $pos) = @_;

        if (substr($$input, $pos) =~ $regex) {
            return { pos => $pos + length $& }
        }
        else {
            return { pos => undef }
        }
    }
}

sub capture {
    my $parser = shift // croak "capture() undefined argument";
    sub {
        my ($rules, $input, $pos) = @_;

        my $start = $pos;
        my $match = $parser->($rules, $input, $pos);

        if (defined $match->{pos}) {
            my @cap;
            push @cap, $match->{cap}->@* if exists $match->{cap};
            push @cap, substr($$input, $start, $match->{pos} - $start);

            return { pos => $match->{pos}, cap => \@cap };
        }
        else {
            return { pos => undef }
        }
    }
}

sub seq {
    my @parsers = @_;
    croak "seq() take at least 1 argument" if !@_;

    sub {
        my ($rules, $input, $pos) = @_;
        my @cap;

        for my $parser (@parsers) {

            my $match = $parser->($rules, $input, $pos);

            if (!defined $match->{pos}) {
                return { pos => undef }
            }

            $pos = $match->{pos};
            push @cap, $match->{cap}->@* if exists $match->{cap};
        }
        return { pos => $pos, cap => \@cap };
    }
}


sub alt {
    my @parsers = @_;
    croak "alt() take at least 1 argument" if !@_;

    sub {
        my ($rules, $input, $pos) = @_;

        for my $parser (@parsers) {
            my $match = $parser->($rules, $input, $pos);

            if (defined $match->{pos}) {
                return $match
            }
        }

        return { pos => undef }
    }
}

sub opt {
    my $parser = shift // croak "opt() undefined argument";
    croak "opt() take exactly 1 argument" if @_;

    return quantifier(0, 1, $parser);
}

sub star {
    my $parser = shift // croak "star() undefined argument";
    croak "star() take exactly 1 argument" if @_;

    return quantifier(0, -1, $parser);
}

sub plus {
    my $parser = shift // croak "plus() undefined argument";
    croak "plus() take exactly 1 argument" if @_;

    return quantifier(1, -1, $parser);
}

sub exact {
    my $count = shift // croak "exact() count undefined";
    my $parser = shift // croak "exact() parser undefined";

    return quantifier($count, $count, $parser);
}

sub min_max {
    my $min = shift // croak "min_max() min undefined";
    my $max = shift // croak "min_max() max undefined";
    my $parser = shift // croak "min_max() parser undefined";

    return quantifier($min, $max, $parser);
}


sub quantifier {
    my ($min, $max, $parser) = @_;

    sub {
        my ($rules, $input, $pos) = @_;
        my @cap;

        for (1 .. $min) {
            my $match = $parser->($rules, $input, $pos);

            if (!defined $match->{pos}) {
                return { pos => undef }
            }

            $pos = $match->{pos};
            push @cap, $match->{cap}->@* if exists $match->{cap};
        }

        if ($max >= 0) {
            for ($min .. $max) {
                my $match = $parser->($rules, $input, $pos);

                if (!defined $match->{pos}) {
                    return { pos => $pos, cap => \@cap }
                }

                $pos = $match->{pos};
                push @cap, $match->{cap}->@* if exists $match->{cap};
            }
        }
        else {
            while (1) {
                my $match = $parser->($rules, $input, $pos);

                if (!defined $match->{pos}) {
                    return { pos => $pos, cap => \@cap }
                }

                $pos = $match->{pos};
                push @cap, $match->{cap}->@* if exists $match->{cap};
            }
        }
    }
}

sub rule {
    my $name = shift // croak "rule() undefined argument";
    croak "rule() argument is not a string" if ref $name ne "";

    sub {
        my ($rules, $input, $pos) = @_;
        my $from = $pos;

        if (!exists $rules->{$name}{rule}) {
            croak "rule '$name' is not defined"
        }

        my $match = $rules->{$name}{rule}->($rules, $input, $pos);

        if (!defined $match->{pos}) {
            return { pos => undef }
        }

        my $rule_capture = { name => $name, cap => [] };
        push $rule_capture->{cap}->@*, $match->{cap}->@* if exists $match->{cap};

        if (exists $rules->{$name}{action}) {
            $rule_capture = $rules->{$name}{action}->($rule_capture);
        }

        return { pos => $match->{pos}, cap => [$rule_capture] }
    };
}


sub parser {
    my %args = @_;
    my %rules;

    while (my ($name, $value) = each %args) {

        if (ref($value) eq "CODE") {
            $rules{$name} = { rule => $value };
        }
        elsif (ref($value) eq "ARRAY"
            && ref($value->[0]) eq "CODE" && ref($value->[1]) eq "CODE")
        {
            $rules{$name} = { rule => $value->[0], action => $value->[1] };
        }
        else {
            croak "rule '$name': incorrect type of value '$value'";
        }
    }

    sub {
        my $input = shift;
        my $match = $rules{top}{rule}->(\%rules, \$input, 0);

        if (!defined $match->{pos}) {
            return undef
        }

        if (exists $rules{top}{action}) {
            return $rules{top}{action}->($match);
        }

        return $match;
    }
}



1;


