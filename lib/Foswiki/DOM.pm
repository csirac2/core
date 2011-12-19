# See bottom of file for default license and copyright

=begin TML

---+ package Foswiki::DOM

A TML (Topic Markup Language) DOM (Document Object Model) for Foswiki.

Foswiki::DOM's mission is to create a tree of Foswiki::DOM::Nodes from TML text
strings. Foswiki::DOM::Transform may then evaluate this structure to produce
reliable, well-formed markup in various formats (Eg. HTML5, XHTML, XML, JSON).

Separately to this, the TOM - Topic Object Model - is concerned with managing
structured data. Merging TOM/DOM architectures may be possible, however, their
specialisations may prove useful: a special (simplified) 'TOM' DOM might be
presented for any TOM data member's TML content when that content is accessed
via the TOM.

Rationale for a DOM:
   * We've been debugging a large pile of regex spaghetti for too long
   * We want TML to be easier to extend in a less bug-prone manner. Especially
     for plugins.
   * Use a common codebase for all TML applications: WYSIWYG, XHTML, HTML5, PDF,
     RTF, XML, JSON etc. so we can fight bugs in one place.
   * We want to avoid wasted effort spent trying to make parallel
     implementations of TML rendering compatible with each other.

=cut

package Foswiki::DOM;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Scalar::Util qw(blessed);
use Foswiki::Func();
use Foswiki::DOM::Scanner();
#use Foswiki::DOM::Transform();

=begin TML

---++ ClassMethod new ($input, $base_addrObj, $markup) -> $domObj

Return a Foswiki::DOM object built by parsing =$input=, which may be:
   * A text string containing TML markup
   * A Foswiki::Address to some resource or part thereof containing TML markup

Foswiki::DOM::Scanner is used to call each of the various syntax scanners which
claim (possibly nested or even overlapping) regions of =$input=.

The result, =$domObj=, an instance of Foswiki::DOM, may be passed to a transform
class such as Foswiki::DOM::Transform::XHTML for evaluation.

=cut

sub new {
    my ( $class, $input, $base_addrObj, $markup ) = @_;
    my $this = {};

    if ( blessed($input) ) {
        ASSERT($input->isa('Foswiki::Address') );
        $this->{input_addrObj} = $input;
        ASSERT( $input->type() eq 'topic',
            'input address types other than topic not yet supported' );
        ( $this->{input} ) =
          Foswiki::Func::readTopic( $input->web(), $input->topic() );
    }
    else {
        $this->{input} = $input;
    }
    $this->{input_orig} = $this->{input};
    if ( blessed($base_addrObj) ) {
        ASSERT($base_addrObj->isa('Foswiki::Address') );
        $this->{base_addrObj} = $base_addrObj;
    }
    $this->{input_markup} = $markup || 'tml';
    bless( $this, $class );
    Foswiki::DOM::Scanner->scan( $this );

    return $this;
}

=begin TML

---++ ObjectMethod finish()

undef and finish all data members. ->finish() helps avoid circular references
which cause perl to leak memory.

Developers should undef all data members to ensure the =finish()= method remains
informative documentation for what data members instances of this class contain.

=cut

sub finish {
    my ($this) = @_;

    $this->{input}         = undef;
    $this->{input_orig}    = undef;
    $this->{input_markup}  = undef;
    $this->{input_addrObj} = undef;
    $this->{base_addrObj}  = undef;

    return;
}

sub trace {
    my ( $class, $msg, $level, $callershift ) = @_;
    $callershift ||= 0;
    my ( $package, $filename, undef, $subroutine ) = caller(1 + $callershift);
    my ( undef, undef, $line ) = caller(0 + $callershift);
    ( undef, undef, $filename ) = File::Spec->splitpath($filename);
    my @pack       = split( '::', $subroutine );
    my $abbr       = '';
    my $context    = Foswiki::Func::getContext();
    my $requestObj = Foswiki::Func::getRequestObject();

    ( undef, undef, $filename ) = File::Spec->splitpath($filename);
    if ( $pack[0] eq 'Foswiki' ) {
        $abbr = '::';
        shift(@pack);
        if ( $pack[0] eq 'Plugins' || $pack[0] eq 'Contrib' ) {
            shift(@pack);
        }
    }
    $abbr .= join( '::', @pack ) . '():' . $line;
    if ( $filename !~ /^$pack[-2]\.pm$/ ) {
        $abbr .= " in $filename";
    }
    $msg = "$abbr:\t$msg";
    if (   !defined $context
        || $requestObj->isa('Unit::Request')
        || $context->{command_line} )
    {
        print STDERR $msg . "\n";
        ASSERT( !defined $level || $level =~ /^[-]?\d+$/ ) if DEBUG;
    }
    else {
        Foswiki::Func::writeDebug($msg);
        print STDERR $msg . "\n";
        if ( defined $level ) {
            ASSERT( $level =~ /^[-]?\d+$/ ) if DEBUG;
            if ( $level == -1 ) {
                print STDERR $msg . "\n";
            }
        }
    }

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
