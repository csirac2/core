# See bottom of file for default license and copyright inNodeion

=begin TML

---+ package Foswiki::DOM::Node::Text

=cut

package Foswiki::DOM::Node::Text;
use strict;
use warnings;

use Assert;
use Foswiki::Func ();    # The plugins API
use Foswiki::Plugins();
use Foswiki::DOM::Node();
our @ISA = ('Foswiki::DOM::Node');

=begin TML

---++ ClassMethod new($content, $dom, %links) -> $nodeObj

   * =%links= 
      * =prev=
      * =next=
      * =parent=
=cut

sub new {
    my ( $class, $content, $dom, %links ) = @_;

    return bless( { %links, content => $content, dom => $dom }, $class );
}

sub finish {
    my ($this) = @_;

    $this->{content} = undef;
    $this->{dom}     = undef;

    return;
}

sub protected {
    my ( $class, $caller ) = @_;

    return 0;
}

sub parse {
    my ( $class, $string, $parent, $root ) = @_;
    my $out   = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split( /(<\/?$tag[^>]*>)/i, $intext ) ) {
        if ( $token =~ /<$tag\b([^>]*)?>/i ) {
            $depth++;
            if ( $depth eq 1 ) {
                $tagParams = $1;
                next;
            }
        }
        elsif ( $token =~ /<\/$tag>/i ) {
            if ( $depth > 0 ) {
                $depth--;
                if ( $depth eq 0 ) {
                    my $placeholder = "$tag$BLOCKID";
                    $BLOCKID++;
                    $map->{$placeholder}{text}   = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= "$OC$placeholder$CC";
                    $scoop = '';
                    next;
                }
            }
        }
        if ( $depth > 0 ) {
            $scoop .= $token;
        }
        else {
            $out .= $token;
        }
    }

    # unmatched tags
    if ( defined($scoop) && ( $scoop ne '' ) ) {
        my $placeholder = "$tag$BLOCKID";
        $BLOCKID++;
        $map->{$placeholder}{text}   = $scoop;
        $map->{$placeholder}{params} = $tagParams;
        $out .= "$OC$placeholder$CC";
    }

    return $this;
}

sub parseTree {
    my ( $class, $parent, $root ) = @_;
    my $siblings  = $parent->kids();
    my $nsiblings = scalar( @{$siblings} );
    my $isibling  = 0;

    while ( $nsiblings < $isibling ) {
        my $node = $siblings->[$isibling];

        if ( ref($node) ) {
            $class->parseTree( $node, $root );
        }
        else {
            $class->parse( $node, $parent, $root );
        }
        $isibling += 1;
    }

    return $tree;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Paul.W.Harvey@csiro.au, http://trin.org.au
Copyright (C) 2010-2011 Foswiki Contributors. Foswiki Contributors
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
