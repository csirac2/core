# See bottom of file for default license and copyright

=begin TML

---+ package Foswiki::DOM

A TML (Topic Markup Language) DOM (Document Object Model) for Foswiki.

The mission is to present a tree of Foswiki::DOM::Node objects from some input
(normally TML string). Evaluators such as Foswiki::DOM::Writer::XHTML then use
this to produce reliable, well-formed output markup (HTML5, XMLs, JSON, etc.).

---++ Discussion

Separately, the TOM - Topic Object Model - is concerned with managing structured
data. Merging TOM & DOM architectures may be possible; on the other hand, it
might prove more useful to retain their specialisations. We could build a special
(simplified) 'TOM' DOM view for any TOM data member's TML content when that
content is accessed via the TOM; eg. the ideal DOM for QuerySearching might look
quite different to one ideal for XHTML rendering; but this remains to be seen.

---++ Rationale for a DOM

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
use File::Spec();
use Foswiki::Func();
use Foswiki::Address();
use Foswiki::DOM::Parser();

#use Foswiki::DOM::Writer();

=begin TML

---++ ClassMethod new ($input, %opts) -> $domObj

Return a Foswiki::DOM object built by processing =$input=, which may be:
   * A text string containing some markup to be parsed (usually TML)
   * A Foswiki::Address to some resource or part thereof containing markup
   * Something else which one of the registered parsers will know how to handle

=%opts=:
   * =base_addr= - =Foswiki::Address= context in which the rendering is assumed
     to be in. Optional, unless the markup cannot be parsed without this
     information (Eg. to expand =%<nop>BASETOPIC%= macro).
   * =input_addr= - =Foswiki::Address= signifying where the =$input= text came
     from. Optional, unless the markup cannot be parsed without this information
     (Eg. to expand =%<nop>TOPIC%= macro). Overrides =$input= if =$input= was a
     =Foswiki::Address=.
   * =input_content_type= - The MIME type of =$input=; one of the registered
     parsers is expected to be able to process it. Defaults to
     =text/vnd.foswiki.wiki= see
     http://foswiki.org/Development/MIMETypeForWikiSyntax

Foswiki::DOM::Parser is used to call the appropriate registered parser for the
=input_content_type= (usually Foswiki::DOM::Parser::TML for TML text string
input) to build the DOM tree.

The result, =$domObj=, an instance of Foswiki::DOM, may then be passed on for
evaluation to Eg. Foswiki::DOM::Writer::XHTML.

=cut

sub new {
    my ( $class, $input, %opts ) = @_;
    my $this = \%opts;

    if ( !$this->{input_addr} && blessed($input) ) {
        $this->{input_addr} = $input;
        $input = undef;
    }
    if ( !defined $input && $this->{input_addr} ) {
        ASSERT(
            (
                blessed( $this->{input_addr} )
                  && $this->{input_addr}->isa('Foswiki::Address')
            ),
            'input_addr is a Foswiki::Address ' . ref( $this->{input_addr} )
        ) if DEBUG;
        ASSERT( $this->{input_addr}->isA('topic'),
            'Foswiki::Address types other than topic aren\'t implemented yet: '
              . $this->{input_addr}->type() )
          if DEBUG;
        ( undef, $this->{input} ) =
          Foswiki::Func::readTopic( $this->{input_addr}->web(),
            $this->{input_addr}->topic() );
    }
    else {
        $this->{input} = $input;
    }
    $this->{input_orig} = $this->{input};
    if ( defined $this->{base_addr} && blessed( $this->{base_addr} ) ) {
        ASSERT( $this->{base_addr}->isa('Foswiki::Address'),
            'base_addr is a Foswiki::Address: ' . ref($this->{base_addr}) )
          if DEBUG;
    }
    elsif (DEBUG) {
        ASSERT(
            ( !defined $this->{base_addr} ),
            'base_addr is a Foswiki::Address'
        ) if DEBUG;
    }
    $this->{input_content_type} ||= 'text/vnd.foswiki.wiki';
    bless( $this, $class );
    Foswiki::DOM::Parser->parse($this);

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

    $this->{input}              = undef;
    $this->{input_orig}         = undef;
    $this->{input_content_type} = undef;
    $this->{input_addr}         = undef;
    $this->{base_addr}          = undef;

    return;
}

sub trace {
    my ( $class, $msg, $level, $callershift ) = @_;
    $callershift ||= 0;
    my ( $package, $filename, undef, $subroutine ) = caller( 1 + $callershift );
    my ( undef, undef, $line ) = caller( 0 + $callershift );
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
    if (ref($msg) eq 'ARRAY') {
        my $string = "$abbr:\t";

        require Data::Dumper;
        foreach my $part (@{$msg}) {
            if (ref($part)) {
                $string .= Data::Dumper->Dump([$part]);
            }
            $string .= $part;
        }
        $msg = $string;
    }
    else {
        $msg = "$abbr:\t$msg";
    }
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

sub warn {
    my ( $class, $msg, $level, $callershift ) = @_;

    $callershift ||= 0;
    $callershift += 1;

    return $class->trace($msg, $level, $callershift);
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
