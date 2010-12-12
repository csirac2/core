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

use Foswiki::Meta ();

# Cache of the names of $Foswiki::cfg items that are accessible
our $isAccessibleCfg;

=begin TML

---++ PUBLIC %aliases
A hash mapping short aliases for META: entry names. For example, this hash
maps 'form' to 'META:FORM'. Published because extensions (search
implementations) have made use of it in the past, though not part of the
offical API.

This hash is maintained by Foswiki::Meta and is *strictly read-only*

---++ PUBLIC %isArrayType
Maps META: entry type names to true if the type is an array type (such as
FIELD, ATTACHMENT or PREFERENCE). Published because extensions (search
implementations) have made use of it in the past, though not part of the
offical API. The type name should be given without the leading 'META:'

This hash is maintained by Foswiki::Meta and is *strictly read-only*

=cut

# These used to be declared here, but have been refactored back into
# Foswiki::Meta
*aliases = \%Foswiki::Meta::aliases;
*isArrayType = \%Foswiki::Meta::isArrayType;

# <DEBUG SUPPORT>

use constant MONITOR_EVAL => 0;
use constant MONITOR_FOLD => 0;

our $emptyExprOp;
our $commaOp;

BEGIN {
    require Foswiki::Query::OP_empty;
    $emptyExprOp = Foswiki::Query::OP_empty->new();
    require Foswiki::Query::OP_comma;
    $commaOp = Foswiki::Query::OP_comma->new();
}

sub emptyExpression {
    my $this = shift;
    return $this->newNode($emptyExprOp);
}

sub toString {
    my ($a) = @_;
    return 'undef' unless defined($a);
    if ( UNIVERSAL::isa( $a, 'Foswiki::Query::Node' ) ) {
        return '{ op => ' . $a->{op} . ', params => ' . toString( $a->{params}
        ) . ' }';
    }
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

# STATIC overrides Foswiki::Infix::Node
# We expand config vars to constant strings during the parse, because
# otherwise we'd have to export the knowledge of config vars out to other
# engines that may evaluate queries instead of the default evaluator.
sub newLeaf {
    my ( $class, $val, $type ) = @_;

    if ( $type == Foswiki::Infix::Node::NAME
           && $val =~ /^({[A-Z][A-Z0-9_]*})+$/i ) {
        # config var name, make sure it's accessible.
        unless (defined $isAccessibleCfg) {
            $isAccessibleCfg =
              { map { $_ => 1 } @{$Foswiki::cfg{AccessibleCFG}} };
        }
        $val = ($isAccessibleCfg->{$val}) ? eval( '$Foswiki::cfg'.$val ) : '';
        return $class->SUPER::newLeaf( $val, Foswiki::Infix::Node::STRING );
    }
    else {
        return $class->SUPER::newLeaf( $val, $type );
    }
}

# Evaluate this node by invoking the operator function named in the 'exec'
# field of the operator. The return result is either an array ref (for many
# results) or a scalar (for a single result)
#
# This is the default evaluator for queries. However it may not be the only
# engine that evaluates them; external engines, such as SQL, might be delegated
# the responsibility of evaluating queries in a search context.
#
# Note that the name resolution simply executes the getField function in the
# query algorithm. It is placed there to allow for Store specific optimisations
# such as direct database lookups.
#
# SMELL: is the getField passed enough domain information? It can see the data
# object (usually a Meta) but cannot see the context of the name in the query.
#
sub evaluate {
    my $this = shift;
    ASSERT( scalar(@_) % 2 == 0 );
    my $result;

    print STDERR ( '-' x $ind ) . $this->stringify() if MONITOR_EVAL;

    if ( !ref( $this->{op} ) ) {
        my %domain = @_;
        if ( $this->{op} == Foswiki::Infix::Node::NAME
            && defined $domain{data} )
        {

	    if (lc($this->{params}[0]) eq 'now') {
		$result = time();
	    } elsif (lc($this->{params}[0]) eq 'undefined') {
		$result = undef;
	    } else {
		# a name; look it up in $domain{data}
		eval "require $Foswiki::cfg{Store}{QueryAlgorithm}";
		die $@ if $@;
		$result = $Foswiki::cfg{Store}{QueryAlgorithm}->getField(
		    $this, $domain{data}, $this->{params}[0] );
	    }
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
    my $c = 0;
    if ( ref( $this->{op} ) ) {
        $c = $this->{op}->evaluatesToConstant( $this, @_ );
    } elsif ($this->{op} == Foswiki::Infix::Node::NUMBER) {
	$c = 1;
    } elsif ($this->{op} == Foswiki::Infix::Node::STRING) {
	$c = 1;
    }
    print STDERR $this->stringify()." is constant\n" if MONITOR_FOLD;
    return $c;
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
        my $c = $this->evaluate(@_);
        $c = 0 unless defined $c;
	$this->_freeze($c);
    }
    else {
        for my $f ( @{ $this->{params} } ) {
            if ( UNIVERSAL::can( $f, 'simplify' ) ) {
                $f->simplify(@_);
            }
        }
    }
}

sub _freeze {
    my ($this, $c) = @_;

    if (ref($c) eq 'ARRAY') {
	$this->_makeArray($c);
    } elsif ( Foswiki::Query::OP::isNumber($c) ) {
	$this->makeConstant(Foswiki::Infix::Node::NUMBER, $c);
    }
    else {
	$this->makeConstant(Foswiki::Infix::Node::STRING, $c);
    }
}

sub _makeArray {
    my ($this, $array) = @_;
    if (scalar(@$array) == 0) {
	$this->{op} = $emptyExprOp;
    } elsif (scalar(@$array) == 1) {
	die unless defined $array->[0];
	$this->_freeze($array->[0]);
    } else {
	$this->{op} = $commaOp;
	$this->{params}[0] = Foswiki::Query::Node->newNode($commaOp);
	$this->{params}[0]->_freeze(shift(@$array));
	$this->{params}[1] = Foswiki::Query::Node->newNode($commaOp);
	$this->{params}[1]->_freeze($array);
    }
}

=begin TML

---++ ObjectMethod tokens() -> []
Provided for compatibility with Foswiki::Search::Node

=cut

sub tokens {
    return [];
}

=begin TML

---++ ObjectMethod isEmpty() -> $boolean
Provided for compatibility with Foswiki::Search::Node

=cut

sub isEmpty {
    return 0;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

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
