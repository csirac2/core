# See bottom of file for license and copyright information
package Foswiki;

use strict;
my @DIG = map { chr($_) } (0..9);

# Returns a decimal number encoded as a string where each digit is
# replaced by an unprintable character
sub _s2d {
    return join('', map { chr(int($_)) } split('', shift));
}

sub _expandEscapes {
    my $s = expandStandardEscapes(shift);
    $s =~ s/\$comma(\(\))?/,/g;
    return $s;
}

sub ENCODE {
    my ( $this, $params ) = @_;

    my $old = $params->{old};
    my $new = $params->{new};
    my $type = $params->{type};

    if (defined $type && (defined $old || defined $new)) {
        return $this->inlineAlert('alerts', 'ENCODE_bad_1');
    }
    if (defined $old && !defined $new || !defined $old && defined $new) {
        return $this->inlineAlert('alerts', 'ENCODE_bad_2');
    }

    my $text = $params->{_DEFAULT};
    $text = '' unless defined $text;

    if (defined $old) {
        my @old = split(',', $old);
        my @new = split(',', $new);
        while (scalar(@new) < scalar(@old)) {
            push(@new, '');
        }
        # The double loop is to make it behave like tr///. The first loop
        # locates the tokens to replace, and the second loop subs them.
        my %toks; # detect repeated tokens
        for (my $i = 0; $i <= $#old; $i++) {
            my $e = _s2d($i);
            my $o = $old[$i];
            if ($toks{$o}) {
                return $this->inlineAlert('alerts', 'ENCODE_bad_3', $o);
            }
            $toks{$o} = 1;
            $o = quotemeta(_expandEscapes($o));
            $text =~ s/$o/$e/ge;
        }
        for (my $i = 0; $i <= $#new; $i++) {
            my $e = _s2d($i);
            my $n = _expandEscapes($new[$i]);
            $text =~ s/$e/$n/g;
        }
        return $text;
    }

    $type ||= 'url';

    if ( $type =~ /^entit(y|ies)$/i ) {
        return entityEncode($text);
    }
    elsif ( $type =~ /^html$/i ) {
        return entityEncode( $text, "\n\r" );
    }
    elsif ( $type =~ /^quotes?$/i ) {

        # escape quotes with backslash (Bugs:Item3383 fix)
        $text =~ s/\"/\\"/go;
        return $text;
    }
    elsif ( $type =~ /^url$/i ) {
        $text =~ s/\r*\n\r*/<br \/>/;    # Legacy.
        return urlEncode($text);
    }
    elsif ( $type =~ /^(off|none)$/i ) {

        # no encoding
        return $text;
    }
    else {                               # safe
                                         # entity encode ' " < > and %
        $text =~ s/([<>%'"])/'&#'.ord($1).';'/ge;
        return $text;
    }
}

1;
__DATA__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
