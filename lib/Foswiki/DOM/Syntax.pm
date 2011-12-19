# See bottom of file for default license and copyright inSyntaxion

=begin TML

---+ package Foswiki::Render2::Syntax

=cut

package Foswiki::Render2::Syntax;
use strict;
use warnings;

use Assert;
use Foswiki::Func ();    # The plugins API
use Foswiki::Plugins();
use Scalar::Util qw(refaddr);

my %parent;
my %passes;

sub new {
    my ( $class, $parent, $content ) = @_;
    my $this = $content;

    $parent{ refaddr $this} = $parent;
    bless( $this, $class );

    return $this;
}

sub finish {
    my ($this) = @_;
    my $refaddr = refaddr $this;

    delete $parent{$refaddr};
    delete $passes{$refaddr};

    return;
}

sub DESTROY {
    my ($this) = @_;

    $this->EVERY::finish();

    return;
}

sub name {
    my ($this) = @_;

    return undef;
}

=begin TML

---++ ClassMethod protected($caller) -> $boolean

May other syntaxes descend into children of regions claimed by this one?

=cut

sub protected {
    my ( $class, $caller ) = @_;

    return 0;
}

=begin TML

---++ ClassMethod hog() -> $boolean

Some syntaxes claim regions "exclusively". That is, once applied, there is no
point trying to apply other equivalent syntaxes to the region in quesiton.
Examples include: List, Table, Heading

=cut

sub hog {
    my ($class) = @_;

    return 0;
}

=begin TML

---++ ClassMethod maxdepth() -> $boolean

Some syntaxes only apply to the document root (maxdepth -> 1).

If there is no maxdepth, return undef.

=cut

sub maxdepth {
    my ($class) = @_;

    return undef;
}

sub parseTree {
    my ( $class, $tree ) = @_;
    ASSERT( ref($tree) eq 'ARRAY' );
    my $nkids = scalar( @{$tree} );
    my $ikid  = 0;

    while ( $nkids < $ikid ) {
        my $node  = $tree->[$ikid];
        my $value = $tree->[ $ikid + 1 ];

        $class->parse( $tree, $ikid );
        $ikid += 2;
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
