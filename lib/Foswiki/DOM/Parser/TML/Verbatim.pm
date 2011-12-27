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

sub TRACE { 0 }

sub priority { return 1000; }

sub scan {
    my ( $class, $dom ) = @_;
    my %state = ( verbatim_count => 0 );
    ASSERT( $dom->isa('Foswiki::DOM') ) if DEBUG;
    my $input_length = length( $dom->{input} ) if DEBUG;

    while ( $dom->{input} =~ /(<(\/)?verbatim\s*([^>]*?)>)/g ) {
        $class->_try_exclude( $dom, \%state, $1, $2, $3 );
    }
    if ( $state{verbatim_count} ) {
        my $input_length = length( $dom->{input} );
        my $begin = $state{begin};

        $dom->warn(
"<verbatim> $state{verbatim_count} tag(s) remain open at end of input"
        );
        ASSERT( defined $begin ) if DEBUG;
        $class->exclude(
            $dom,
            node_class => 'Foswiki::DOM::Node::Verbatim',
            do_replace => 1,
            begin      => $begin,
            end        => $input_length,
            length     => $input_length - $begin
        );
    }
    $dom->trace( [ "DOM INPUT: ", $dom->{input} ] ) if TRACE;
    ASSERT( length( $dom->{input} ) == $input_length ) if DEBUG;

    return;
}

sub _try_exclude {
    my ( $class, $dom, $state, $tag, $slash, $tagattrs ) = @_;

    if ($slash) {
        if ( $state->{verbatim_count} ) {
            $state->{verbatim_count} -= 1;
            if ( !$state->{verbatim_count} ) {
                my $begin = $state->{begin};

                $class->trace("</verbatim>, final closing tag") if TRACE;
                $state->{end} = pos( $dom->{input} );

                #$state->{end}       = $state->{end_start} + length($tag);
                #ASSERT( defined $state->{end_start} )             if DEBUG;
                ASSERT( defined $begin ) if DEBUG;

                #ASSERT( $state->{end} >= $state->{end_start} )    if DEBUG;
                ASSERT( $state->{end} >= $begin ) if DEBUG;
                $state->{length} = $state->{end} - $begin;
                $class->exclude(
                    $dom,
                    node_class => 'Foswiki::DOM::Node::Verbatim',
                    do_replace => 1,
                    %{$state}
                );
                delete $state->{begin};

                #delete $state->{end_start};
                delete $state->{end};
            }
            else {
                $class->trace(
"  </verbatim> was nested, $state->{verbatim_count} <verbatim> tags remain open"
                ) if TRACE;
            }
        }
        else {
            my $end       = pos( $dom->{input} );
            my $end_start = $end - length($tag);

            ASSERT( defined $end_start ) if DEBUG;
            $class->warn(
                "</verbatim> encountered but no <verbatim> tags are open");
            ASSERT( !defined $state->{begin} )     if DEBUG;
            ASSERT( !defined $state->{end_start} ) if DEBUG;
            ASSERT( !defined $state->{end} )       if DEBUG;
            $class->exclude(
                $dom,
                node_class => 'Foswiki::DOM::Node::Verbatim',
                do_replace => 1,
                begin      => $end_start,
                end        => $end,
                length     => $end - $end_start
            );
        }
    }
    elsif ( $state->{verbatim_count} > 0 ) {
        $state->{verbatim_count} += 1;
        $class->trace(
"  <verbatim> was nested, $state->{verbatim_count} <verbatim> tags now open"
        ) if TRACE;
    }
    else {
        $class->trace("<verbatim> start")      if TRACE;
        ASSERT( !defined $state->{begin} )     if DEBUG;
        ASSERT( !defined $state->{end_start} ) if DEBUG;
        ASSERT( !defined $state->{end} )       if DEBUG;
        ASSERT( defined pos( $dom->{input} ) ) if DEBUG;
        $state->{begin} = pos( $dom->{input} ) - length($tag);
        $state->{verbatim_count} += 1;
    }
    ASSERT( !defined $state->{end} || $state->{end} <= length( $dom->{input} ) )
      if DEBUG;

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
