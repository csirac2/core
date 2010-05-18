# See bottom of file for license and copyright information

#
# Data type for an perl constant rvalue. This is used for capturing values
# of collection types.
# The value must observe the following grammar:
# value :: array | hash | string ;
# array :: '[' value ( ',' value )* ']' ;
# hash  :: '{' keydef ( ',' keydef )* ']';
# keydef :: string '=>' value ;
# string ::= single quoted string, use \' to escape a quote, or \w+

package Foswiki::Configure::Types::PERL;

use strict;
use warnings;

use Foswiki::Configure::Type ();
our @ISA = ('Foswiki::Configure::Type');

use Data::Dumper ();

sub prompt {
    my ( $this, $id, $opts, $value, $class ) = @_;

    my $v = Data::Dumper->Dump( [$value], ['x'] );
    $v =~ s/^\$x = (.*);\s*$/$1/s;
    $v =~ s/^     //gm;

    # Force textarea
    my $size = $Foswiki::DEFAULT_FIELD_WIDTH_NO_CSS;
    $opts .= " ${size}x10" unless ( $opts =~ /\b(\d+)x(\d+)\b/ );

    return $this->SUPER::prompt( $id, $opts, $v, $class );
}

# verify that the string is a legal rvalue according to the grammar
sub _rvalue {
    my ( $s, $term ) = @_;
    while ( length($s) > 0 && ( !$term || $s !~ s/^\s*$term// ) ) {
        if ( $s =~ s/^\s*'//s ) {
            my $escaped = 0;
            while ( length($s) > 0 && $s =~ s/^(.)//s ) {
                last if ( $1 eq "'" && !$escaped );
                $escaped = $1 eq '\\';
            }
        }
        elsif ( $s =~ s/^\s*(\w+)//s ) {
        }
        elsif ( $s =~ s/^\s*\[//s ) {
            $s = _rvalue( $s, ']' );
        }
        elsif ( $s =~ s/^\s*{//s ) {
            $s = _rvalue( $s, '}' );
        }
        elsif ( $s =~ s/^\s*(,|=>)//s ) {
        }
        else {
            last;
        }
    }
    return $s;
}

sub string2value {
    my ( $this, $val ) = @_;

    $val =~ s/^[[:space:]]+(.*?)$/$1/s;    # strip at start
    $val =~ s/^(.*?)[[:space:]]+$/$1/s;    # strip at end

    my $s;
    if ( $s = _rvalue($val) ) {

        # Parse failed, return as a string.
        die
"Could not parse text to a data structure (at: $s)\nPlease go back and check if the text has the correct syntax.";
    }
    $val =~ /(.*)/s;                       # parsed, so safe to untaint
    return eval $1;
}

sub deep_equals {
    my ( $a, $b ) = @_;

    if ( !defined($a) && !defined($b) ) {
        return 1;
    }
    if ( !defined($a) || !defined($b) ) {
        return 0;
    }
    if ( ref($a) eq 'ARRAY' && ref($b) eq 'ARRAY' ) {
        return 0 unless scalar(@$a) == scalar(@$b);
        for ( 0 .. $#$a ) {
            return 0 unless deep_equals( $a->[$_], $b->[$_] );
        }
        return 1;
    }

    if ( ref($a) eq 'HASH' && ref($b) eq 'HASH' ) {
        return 0 unless scalar( keys %$a ) == scalar( keys %$b );
        for ( keys %$a ) {
            return 0 unless deep_equals( $a->{$_}, $b->{$_} );
        }
        return 1;
    }
    return $a eq $b;
}

sub equals {
    my ( $this, $val, $def ) = @_;

    return deep_equals( $val, $def );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
