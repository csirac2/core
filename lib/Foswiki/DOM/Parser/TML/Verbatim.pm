# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Parser::TML::Verbatim

=cut

package Foswiki::DOM::Parser::TML::Verbatim;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Parser::TML();
our @ISA = ('Foswiki::DOM::Parser::TML');

sub TRACE { 1 }

sub WARN { 1 }

sub priority { return 1000; }

sub scan {
    my ( $class, $dom ) = @_;
    my %state = ( verbatim_count => 0 );

    ASSERT( $dom->isa('Foswiki::DOM') ) if DEBUG;
    $dom->{input} =~ s/(<(\/)?verbatim\s*([^>]*?)>)/
        $class->_try_claim($dom, \%state, $1, $2, $3)
        /gemx;

    return;
}

sub _try_claim {
    my ( $class, $dom, $state, $tag, $slash, $tagattrs ) = @_;
    my $vanished;

    if ($slash) {
        if ( $state->{verbatim_count} ) {
            $state->{verbatim_count} -= 1;
            if ( !$state->{verbatim_count} ) {
                my $taglength = length($tag);

                $class->trace("</verbatim>, final closing tag") if TRACE;
                $state->{end}       = pos( $dom->{input} );
                $state->{end_start} = $state->{end} - $taglength;
                ASSERT( $state->{begin} )      if DEBUG;
                ASSERT( $state->{begin_stop} ) if DEBUG;
                $class->claim( $dom, %{$state} );
                delete $state->{begin};
                delete $state->{begin_stop};
                delete $state->{end_start};
                delete $state->{end};
            }
            else {
                $class->trace("  </verbatim> inside a verbatim") if TRACE;
            }
        }
        else {
            my $taglength = length($tag);
            my $end       = pos( $dom->{input} );

            $class->warn("</verbatim> without any matching start :-(")
              if WARN;
            ASSERT( !$state->{begin} )      if DEBUG;
            ASSERT( !$state->{begin_stop} ) if DEBUG;
            ASSERT( !$state->{end_start} )  if DEBUG;
            ASSERT( !$state->{end} )        if DEBUG;
            $vanished =
              $class->vanish( $dom, begin => $end - $taglength, end => $end );
        }
    } elsif ( $state->{verbatim_count} > 0 ) {
        $class->trace("  <verbatim ...> inside a verbatim") if TRACE;
        $state->{verbatim_count} += 1;
    }
    else {
        my $taglength = length($tag);

        $class->trace("<verbatim ...>, start") if TRACE;
        ASSERT( !$state->{begin} )             if DEBUG;
        ASSERT( !$state->{begin_stop} )        if DEBUG;
        ASSERT( !$state->{end_start} )         if DEBUG;
        ASSERT( !$state->{end} )               if DEBUG;
        $state->{begin_stop} = pos( $dom->{input} );
        $state->{begin}      = $state->{begin_stop} - $taglength;
        $state->{verbatim_count} += 1;
    }

    return $vanished || $tag;
}

sub claim {
    my ($class, $dom, %opts) = @_;

    require Data::Dumper;
    print Data::Dumper->Dump([$dom, %opts]);

    return;
}

1;

__END__
Author: Paul.W.Harvey@csiro.au, http://trin.org.au

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
