# See bottom of file for default license and copyright insyntaxion

=begin_markup TML

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
        my $begin_markup = $state{begin_markup};

        $dom->warn(
"<verbatim> $state{verbatim_count} tag(s) remain open at end_markup of input"
        );
        ASSERT( defined $begin_markup ) if DEBUG;
        ASSERT( defined $state{begin_content} ) if DEBUG;
        $class->exclude(
            $dom,
            node_class    => 'Foswiki::DOM::Node::Verbatim',
            do_replace    => 1,
            begin_markup  => $begin_markup,
            begin_content => $state{begin_content},
            end_markup    => $input_length,
            end_content   => $input_length,
            length        => $input_length - $begin_markup
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
                my $begin_markup = $state->{begin_markup};

                $class->trace("</verbatim>, final closing tag") if TRACE;
                $state->{end_markup}  = pos( $dom->{input} );
                $state->{end_content} = pos( $dom->{input} ) - length($tag);
                ASSERT( defined $state->{begin_content} ) if DEBUG;
                ASSERT( defined $state->{begin_markup} )  if DEBUG;
                ASSERT( $state->{end_markup} >= $state->{begin_markup} )
                  if DEBUG;
                ASSERT( $state->{end_markup} >= $state->{end_content} )
                  if DEBUG;
                ASSERT( $state->{begin_markup} <= $state->{begin_content} )
                  if DEBUG;
                $state->{length} = $state->{end_markup} - $begin_markup;
                $class->exclude(
                    $dom,
                    node_class => 'Foswiki::DOM::Node::Verbatim',
                    do_replace => 1,
                    %{$state}
                );
                delete $state->{begin_markup};
                delete $state->{begin_content};
                delete $state->{end_content};
                delete $state->{end_markup};
            }
            else {
                $class->trace(
"  </verbatim> was nested, $state->{verbatim_count} <verbatim> tags remain open"
                ) if TRACE;
            }
        }
        else {
            my $tag_length  = length($tag);
            my $end_markup  = pos( $dom->{input} );
            my $end_content = $end_markup - $tag_length;

            ASSERT( defined $end_content ) if DEBUG;
            $class->warn(
                "</verbatim> encountered but no <verbatim> tags are open");
            ASSERT( !defined $state->{begin_markup} )  if DEBUG;
            ASSERT( !defined $state->{begin_content} ) if DEBUG;
            ASSERT( !defined $state->{end_content} )   if DEBUG;
            ASSERT( !defined $state->{end_markup} )    if DEBUG;
            $class->exclude(
                $dom,
                node_class    => 'Foswiki::DOM::Node::Verbatim',
                do_replace    => 1,
                begin_markup  => $end_content,
                begin_content => $end_content,
                end_markup    => $end_markup,
                end_content   => $end_content,
                length        => $tag_length
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
        $class->trace("<verbatim> start")          if TRACE;
        ASSERT( !defined $state->{begin_markup} )  if DEBUG;
        ASSERT( !defined $state->{begin_content} ) if DEBUG;
        ASSERT( !defined $state->{end_content} )   if DEBUG;
        ASSERT( !defined $state->{end_markup} )    if DEBUG;
        ASSERT( defined pos( $dom->{input} ) )     if DEBUG;
        $state->{begin_markup}  = pos( $dom->{input} ) - length($tag);
        $state->{begin_content} = pos( $dom->{input} );
        $state->{verbatim_count} += 1;
    }
    ASSERT( !defined $state->{end_markup}
          || $state->{end_markup} <= length( $dom->{input} ) )
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
