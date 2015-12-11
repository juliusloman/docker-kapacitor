#!/usr/bin/perl

use strict;
use base qw(Exporter);

our ($VERSION, @EXPORT, $SYNTAX_ERROR, @_NAMESPACE);

use B;
use Carp qw(croak);
use Text::Balanced qw(extract_bracketed);

$VERSION = "0.91";
@EXPORT = qw(from_toml to_toml);
$SYNTAX_ERROR = q(Syntax error);

sub to_toml {
    my $stuff = shift;
    local @_NAMESPACE = ();
    _to_toml($stuff);
}

sub _to_toml {
    my ($stuff) = @_;

    if (ref $stuff eq 'HASH') {
        my $res = '';
        my @keys = sort keys %$stuff;
        for my $key (grep { ref $stuff->{$_} ne 'HASH' } @keys) {
            my $val = $stuff->{$key};
            $res .= "$key = " . _serialize($val) . "\n";
        } 
        for my $key (grep { ref $stuff->{$_} eq 'HASH' } @keys) {
            my $val = $stuff->{$key};
            local @_NAMESPACE = (@_NAMESPACE, $key);
            $res .= sprintf("[%s]\n", join(".", @_NAMESPACE));
            $res .= _to_toml($val);
	    $res .= "\n";
        } 
        return $res;
    } else {
        croak("You cannot convert non-HashRef values to TOML");
    }
}

sub _serialize {
    my $value = shift;
    my $b_obj = B::svref_2object(\$value);
    my $flags = $b_obj->FLAGS;

    return $value
        if $flags & ( B::SVp_IOK | B::SVp_NOK ) and !( $flags & B::SVp_POK ); # SvTYPE is IV or NV?

    my $type = ref($value); 
    if (!$type) {
        return string_to_json($value);
    } elsif ($type eq 'ARRAY') {
        return sprintf('[%s]', join(", ", map { _serialize($_) } @$value));
    } elsif ($type eq 'SCALAR') {
        if (defined $$value) {
            if ($$value eq '0') {
                return 'false';
            } elsif ($$value eq '1') {
                return 'true';
            } else {
                croak("cannot encode reference to scalar");
            }
        }
        croak("cannot encode reference to scalar");
    }
    croak("Bad type in to_toml: $type");
}

my %esc = (
    "\n" => '\n',
    "\r" => '\r',
    "\t" => '\t',
    "\f" => '\f',
    "\b" => '\b',
    "\"" => '\"',
    "\\" => '\\\\',
    "\'" => '\\\'',
);
sub string_to_json {
    my ($arg) = @_;

    if (($arg =~ /^[+-]?[\d.]+$/) ||
       ($arg =~ /^true|false$/) ||
       ($arg =~ /^\[.*\]$/))
    {
	return $arg;
    } else  { 
       $arg =~ s/([\x22\x5c\n\r\t\f\b])/$esc{$1}/g;
       $arg =~ s/([\x00-\x08\x0b\x0e-\x1f])/'\\u00' . unpack('H2', $1)/eg;
        return '"' . $arg . '"';
    }
}

sub from_toml {
    my $string = shift;
    my %toml;   # Final data structure
    my $cur;
    my $err;    # Error
    my $lineno = 0;

    # Normalize
    $string =
        join "\n",
        grep !/^$/,
        map { s/^\s*//; s/\s*$//; $_ } 
        map { s/#.*//; $_ }
        split /[\n\r]/, $string;

    while ($string) {
        # strip leading whitespace, including newlines
        $string =~ s/^\s*//s;
        $lineno++;

        # Store current value, to check for invalid syntax
        my $string_start = $string;

        # Strings
        if ($string =~ s/^(\S+)\s*=\s*"([^"]*)"\s*//) {
            my $key = "$1";
            my $val = "$2";
            $val =~ s/^"//;
            $val =~ s/"$//;
            $val =~ s/\\0/\x00/g;
            $val =~ s/\\t/\x09/g;
            $val =~ s/\\n/\x0a/g;
            $val =~ s/\\r/\x0d/g;
            $val =~ s/\\"/\x22/g;
            $val =~ s/\\\\/\x5c/g;

            if ($cur) {
                $cur->{ $key } = $val;
            }
            else {
                $toml{ $key } = $val;
            }
        }

        # Boolean
        if ($string =~ s/^(\S+)\s*=\s*(true|false)//i) {
            my $key = "$1";
            my $num = lc($2) eq "true" ? "true" : "false";
            if ($cur) {
                $cur->{ $key } = $num;
            }
            else {
                $toml{ $key } = $num;
            }
        }

        # Date
        if ($string =~ s/^(\S+)\s*=\s*(\d\d\d\d\-\d\d\-\d\dT\d\d:\d\d:\d\dZ)\s*//) {
            my $key = "$1";
            my $date = "$2";
            if ($cur) {
                $cur->{ $key } = $date;
            }
            else {
                $toml{ $key } = $date;
            }
        }

        # Numbers
        if ($string =~ s/^(\S+)\s*=\s*([+-]?[\d.]+)(?:\n|\z)//) {
            my $key = "$1";
            my $num = $2;
            if ($cur) {
                $cur->{ $key } = $num;
            }
            else {
                $toml{ $key } = $num;
            }
        }

        # Arrays
        if ($string =~ s/^(\S+)\s=\s*(\[)/[/) {
            my $key = "$1";
            my $match;
            ($match, $string) = extract_bracketed($string, "[]");
            if ($cur) {
                $cur->{ $key } = eval $match || $match;
            }
            else {
                $toml{ $key } = eval $match || $match;
            }
        }

        # New section
        elsif ($string =~ s/^\[([^]]+)\]\s*//) {
            my $section = "$1";
            $cur = undef;
            my @bits = split /\./, $section;

            for my $bit (@bits) {
                if ($cur) {
                    $cur->{ $bit } ||= { };
                    $cur = $cur->{ $bit };
                }
                else {
                    $toml{ $bit } ||= { };
                    $cur = $toml{ $bit };
                }
            }
        }

        if ($string eq $string_start) {
            # If $string hasn't been modified by this point, then
            # it contains invalid syntax.
           (my $err_bits = $string) =~ s/(.+?)\n.*//s;
            return wantarray ? (undef, "$SYNTAX_ERROR at line $lineno: $err_bits") : undef;
        }
    }

    return wantarray ? (\%toml, $err) : \%toml;
}


# Parsing toml
my $toml="";
open(CONFIG, $ARGV[0]);
while (my $line = <CONFIG>) {
	$toml.=$line;
}
close(CONFIG);
my $data = from_toml($toml);

for my $key(keys %ENV) {
	if ($key=~/^kapacitor_(.*)/i) {
		my $confkey=$1;
		if ($confkey=~/^(.*)_(.*)$/) {
			print "($0) - Setting key \"$2\" in section \"$1\" to \"$ENV{$key}\"\n";
			$data->{$1}{$2}=$ENV{$key};
		} else {
			print "($0) Setting key \"$confkey\" in global section to \"$ENV{$key}\"\n";
			$data->{$confkey}=$ENV{$key};
		}
	}
}

print "Writing to $ARGV[1]\n";
open (CONFIG, ">".$ARGV[1]);
print CONFIG to_toml($data);
close(CONFIG);

