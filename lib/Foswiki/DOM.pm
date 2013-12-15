# See bottom of file for default license and copyright

=begin TML

---+ package Foswiki::DOM

A DOM (Document Object Model) for Foswiki, optimized for holding TML (Topic
Markup Language).

---++ Description

The mission is to present a tree of Foswiki::DOM::Node objects from some input
(normally TML string). Evaluators such as Foswiki::DOM::Writer::XHTML then use
this to produce reliable, well-formed output markup (HTML5, XMLs, JSON, etc.).

---+++ Discussion

Separately, the TOM - Topic Object Model - is concerned with managing structured
data. Merging TOM & DOM architectures may be possible; on the other hand, their
specialisations may prove useful. A special (simplified) 'TOM' DOM view might be
possible for any TOM data member's TML content when that content is accessed via
the TOM; eg. the ideal DOM for QuerySearching might look different to one ideal
for (reversible) TML &lt;-&gt; XHTML rendering; but this remains to be proven.

---+++ Rationale for a DOM

   * The venerable Foswiki::Render has served well, but untangling and changing
     this web of regex spaghetti is daunting
   * Extending (and/or re-purposing) TML is full of surprises & edge cases,
     opaque re-(de)-escaping/evaluation/takeout/putback tricks... A DOM should
     make this easier, more consistent, less bug-prone. Especially for plugins.
   * Use a common codebase for all TML applications: WYSIWYG, XHTML, HTML5, RTF,
     XML, JSON etc. so we can fight bugs in one place.
   * Avoid wasted effort in parallel TML rendering implementations of varying
     completeness/bug-compatibility
   * Most other wiki & CMS platforms have a DOM for their wikitext: Mediawiki,
     Confluence, X-Wiki, etc.
      * _But does using a DOM erode some of Foswiki's approachability,
        hackability, 'charm'?_ - hopefully Foswiki::DOM::Parser::Scanner code
        such as Foswiki::DOM::Parser::TML::Verbatim feels familiar to regex
        hackers, given its approach of claiming regions of syntax first,
        leaving the complexity of building/optimizing tree structures from these
        ranges up to a separate, syntax/feature-agnostic step
   * Could allow native storage of content in markups other than TML
   * Could cache the Foswiki::DOM tree, possibly enabling performance
     improvements (or making up for lost perf over Foswiki::Render)

---+++ TODO
   * What's the performance cost/benefit?
   * Justify why Foswiki::DOM::Node isn't compatible with CPAN:XML::XPath::Node
     which could allow us to easily make use of Eg. CPAN:XML::XPathEngine

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

my $default_debug_level = 5;
my $debug_level         = 5;

=begin TML

---++ ClassMethod new ($input, %opts) -> $domObj

Return a Foswiki::DOM object built by processing =$input=, which may be:
   * A text string containing some markup to be parsed (usually TML)
   * A Foswiki::Address to some resource or part thereof containing markup
   * Something else which one of the registered parsers will know how to handle

=%opts=:
   * =base_addr= - =Foswiki::Address= context in which the DOM will be
     evaluated. Optional, unless the markup cannot be parsed without it
   * =input_addr= - =Foswiki::Address= signifying where the =$input= string came
     from. Optional, unless the markup cannot be parsed without it. Overrides
     =$input= if =$input= was a =Foswiki::Address=.
   * =input_content_type= - The MIME type of =$input=; one of the registered
     parsers is expected to be compatible with it. Defaults to
     =text/vnd.foswiki.wiki= ( see
     http://foswiki.org/Development/MIMETypeForWikiSyntax )

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
            'input_addr is a Foswiki::Address: ' . ref( $this->{input_addr} )
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
            'base_addr is a Foswiki::Address: ' . ref( $this->{base_addr} ) )
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

Additionally, developers should ensure all data members are undef'd here to
maintain documentation for what data members instances of this class use.

=cut

sub finish {
    my ($this) = @_;

    $this->{input}              = undef;
    $this->{input_orig}         = undef;
    $this->{input_content_type} = undef;
    $this->{input_addr}->finish() if defined $this->{input_addr};
    $this->{input_addr} = undef;
    $this->{base_addr}->finish() if defined $this->{base_addr};
    $this->{base_addr} = undef;

    return;
}

=begin TML

---++ ClassMethod trace($thing, $level, $callershift) = @_;

Foswiki::DOM code uses =$foo->trace(...) if TRACE;= instead of =print STDERR
... if TRACE;=

It decorates the output with caller information automatically, adding context
to the debug messages.

It strips =Foswiki= from the front of the namespace, and also truncates all
namespace elements but the last three (if the namespace is deeper than 4). For
example, this call to =->trace= from Foswiki::DOM::Parser::TML::parse():
<verbatim class="perl">Foswiki::DOM->trace('hello')</verbatim>

Might print something like this:
<verbatim>::DOM::Parser::TML::parse():67:  hello</verbatim>

   * =$thing= - scalar text string OR an array ref of stuff to emit with
   Data::Dumper. Things in the array which are refs are Data::Dumper->Dump'd
   separately; everything else (normal text strings) are printed directly.
   * =$level= - 'debug level' - starting from 1 (which might be squelched if
   running debuglevel 0) or -1 (negative levels are never squelched). The bigger
   this number, the less important (more noisy) the message.
   * =$callershift= - because this method prints (part of) the namespace, sub &
   line number from which the =->trace= call is made, packages which wrap calls
   to Foswiki::DOM->trace() need to add 1 to the =$callershift= value (which
   starts at zero) so that debug messages are showing calls from the outermost
   =->trace()= call rather than in the wrapper's call.

See also: =Foswiki::DOM->warn()=

=cut

sub trace {
    my ( $class, $msg, $level, $callershift, @junk ) = @_;
    $callershift ||= 0;
    ASSERT( !defined $level || $level =~ /^[-\+]?\d+$/ ) if DEBUG;
    ASSERT( $callershift =~ /^\d+$/ ) if DEBUG;
    ASSERT( !scalar(@junk) ) if DEBUG;
    my ( $package, undef, undef, $subroutine ) = caller( 1 + $callershift );
    my ( undef, $filename, $line ) = caller( 0 + $callershift );
    my @pack       = split( '::', $subroutine );
    my $abbr       = '';
    my $context    = Foswiki::Func::getContext();
    my $requestObj = Foswiki::Func::getRequestObject();

    $level ||= $default_debug_level;
    ( undef, undef, $filename ) = File::Spec->splitpath($filename);
    if ( $pack[0] eq 'Foswiki' ) {
        $abbr = '::';
        shift(@pack);
        if ( $pack[0] eq 'Plugins' || $pack[0] eq 'Contrib' ) {
            shift(@pack);
        }
    }
    if ( scalar(@pack) > 4 ) {
        @pack = @pack[ -4 .. -1 ];
    }
    $abbr .= join( '::', @pack ) . '():' . $line;
    if ( $filename !~ /^$pack[-2]\.pm$/ ) {
        $abbr .= " in $filename";
    }
    if ( ref($msg) eq 'ARRAY' ) {
        my $string = "$abbr:\t";

        require Data::Dumper;
        foreach my $part ( @{$msg} ) {
            if ( ref($part) ) {
                $string .= Data::Dumper->Dump( [$part] );
            }
            else {
                $string .= $part . "\n";
            }
        }
        $msg = $string;
    }
    else {
        $msg = "$abbr:\t$msg";
    }
    ASSERT( !defined $level || $level =~ /^[-]?\d+$/ ) if DEBUG;
    if ( defined $level && $level < 0 ) {
        print STDERR $msg . "\n";
        Foswiki::Func::writeDebug($msg);
    }
    elsif ( ( defined $level ? $level : 5 ) <= $debug_level ) {
        if (   !defined $context
            || $requestObj->isa('Unit::Request')
            || $context->{command_line} )
        {
            print STDERR $msg . "\n";
        }
        else {
            Foswiki::Func::writeDebug($msg);
        }
    }

    return;
}

=begin TML

---++ ClassMethod warn($thing, $level, $callershift)

Wrapper to Foswiki::DOM->trace()

Ensures =$level= is always negative, defaulting to =$level= of =-1=, which means
messages are usually emitted regardless of any global debug =$level= which would
normall squelch some or all =trace()= messages.

=cut

sub warn {
    my ( $class, $msg, $level, $callershift, @junk ) = @_;

    ASSERT( !defined $callershift || $callershift =~ /^\d+$/ )       if DEBUG;
    ASSERT( !defined $level       || $level       =~ /^[-\+]?\d+$/ ) if DEBUG;
    ASSERT( !scalar(@junk) ) if DEBUG;
    if ( !defined $level ) {
        $level = -1;
    }
    elsif ( $level > 0 ) {
        $level = -$level;
    }
    $callershift ||= 0;
    $callershift += 1;

    return $class->trace( $msg, $level, $callershift );
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
