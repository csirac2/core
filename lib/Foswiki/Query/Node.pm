# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::Node

A Query object is a representation of a query over the Foswiki database.

Fields are given by name, and values by strings or numbers. Strings should always be surrounded by 'single-quotes'. Numbers can be signed integers or decimals. Single quotes in values may be escaped using backslash (\).

See %SYSTEMWEB%.QuerySearch for details of the query language. At the time of writing
only a subset of the entire query language is supported, for use in searching.

A query object implements the =evaluate= method as its general
contract with the rest of the world. This method does a "hard work" evaluation
of the parser tree. Of course, smarter Store implementations should be
able to do it better....

The "hard work" evaluation uses the =getField= method in the
{Store}{QueryAlgorithm} to get data from the store. This decouples the query
object from the detail of the store.

See Foswiki::Store::QueryAlgorithms for a full spec of the interface to
query algorithms.

=cut

package Foswiki::Query::Node;
use strict;
use warnings;
use Foswiki::Infix::Node ();
our @ISA = ('Foswiki::Infix::Node');

use Assert;
use Error qw( :try );

=begin TML

---++ PUBLIC $aliases
A hash mapping short aliases for META: entry names. For example, this hash
maps 'form' to 'META:FORM'. Published so extensions can extend the range
of supported types.

---++ PUBLIC %isArrayType
Maps META: entry type names to true if the type is an array type (such as
FIELD, ATTACHMENT or PREFERENCE). Published so extensions can extend the range
of supported types. The type name should be given without the leading 'META:'

=cut

our %aliases = (
    attachments => 'META:FILEATTACHMENT',
    fields      => 'META:FIELD',
    form        => 'META:FORM',
    info        => 'META:TOPICINFO',
    moved       => 'META:TOPICMOVED',
    parent      => 'META:TOPICPARENT',
    preferences => 'META:PREFERENCE',
);

our %isArrayType =
  map { $_ => 1 } qw( FILEATTACHMENT FIELD PREFERENCE );

# <DEBUG SUPPORT>

sub MONITOR_EVAL { 0 }

sub toString {
    my ($a) = @_;
    return 'undef' unless defined($a);
    if ( ref($a) eq 'ARRAY' ) {
        return '[' . join( ',', map { toString($_) } @$a ) . ']';
    }
    if ( ref($a) eq 'HASH' ) {
        return
          '{'
          . join( ',', map { "$_=>" . toString( $a->{$_} ) } keys %$a ) . '}';
    }
    if ( UNIVERSAL::isa( $a, 'Foswiki::Meta' ) ) {
        return $a->stringify();
    }
    return $a;
}

my $ind = 0;

# </DEBUG SUPPORT>

# Evaluate this node by invoking the operator function named in the 'exec'
# field of the operator. The return result is either an array ref (for many
# results) or a scalar (for a single result)
#
# this function is a stub to execute the getField function in the
# query algorithm. It is placed there to allow for Store specific optimisations
# such as direct database lookups.
sub evaluate {
    my $this = shift;
    ASSERT( scalar(@_) % 2 == 0 );
    my $result;

    print STDERR ( '-' x $ind ) . $this->stringify() if MONITOR_EVAL;

    if ( !ref( $this->{op} ) ) {
        my %domain = @_;
        if ( $this->{op} == $Foswiki::Infix::Node::NAME
            && defined $domain{data} )
        {

            # a name; look it up in $domain{data}
            eval "require $Foswiki::cfg{Store}{QueryAlgorithm}";
            die $@ if $@;
            $result =
              $Foswiki::cfg{Store}{QueryAlgorithm}
              ->getField( $this, $domain{data}, $this->{params}[0] );
        }
        else {
            $result = $this->{params}[0];
        }
    }
    else {
        print STDERR " {\n" if MONITOR_EVAL;
        $ind++ if MONITOR_EVAL;
        $result = $this->{op}->evaluate( $this, @_ );
        $ind-- if MONITOR_EVAL;
        print STDERR ( '-' x $ind ) . '}' . $this->{op}->{name} if MONITOR_EVAL;
    }
    print STDERR ' -> ' . toString($result) . "\n" if MONITOR_EVAL;

    return $result;
}

=begin TML

---++ evaluatesToConstant(%opts)

Determine if this node evaluates to a constant or not. "Constant" is defined
as "anything that doesn't involve actually looking in searched topics".
This function takes the same parameters (%domain) as evaluate(). Note that
no reference to the tom or data web or topic will be made, so you can
simply pass an arbitrary Foswiki::Meta.

=cut

sub evaluatesToConstant {
    my $this = shift;
    if (
        !ref( $this->{op} )
        && (   $this->{op} == $Foswiki::Infix::Node::NUMBER
            || $this->{op} == $Foswiki::Infix::Node::STRING )
      )
    {
        return 1;
    }
    elsif ( ref( $this->{op} ) ) {
        return $this->{op}->evaluatesToConstant( $this, @_ );
    }
    return 0;
}

=begin TML

---++ simplify(%opts)

Simplify the query by spotting constant expressions and evaluating them,
replacing the constant expression with an atomic value in the expression tree.
This function takes the same parameters (%domain) as evaluate(). Note that
no reference to the tom or data web or topic will be made, so you can
simply pass an arbitrary Foswiki::Meta.

=cut

sub simplify {
    my $this = shift;

    if ( $this->evaluatesToConstant(@_) ) {
        my $c = $this->evaluate(@_) || 0;
        if ( $c =~ /^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/ ) {
            $this->{op} = $Foswiki::Infix::Node::NUMBER;
        }
        else {
            $this->{op} = $Foswiki::Infix::Node::STRING;
        }
        @{ $this->{params} } = ($c);
    }
    else {
        for my $f ( @{ $this->{params} } ) {
            if ( UNIVERSAL::can( $f, 'simplify' ) ) {
                $f->simplify(@_);
            }
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
