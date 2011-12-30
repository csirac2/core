# See bottom of file for default license and copyright insyntaxion

=begin_markup TML

---+ package Foswiki::DOM::Parser::TML::Macro

=cut

package Foswiki::DOM::Parser::TML::Macro;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki();
use Foswiki::DOM::Parser::TML();
our @ISA = ('Foswiki::DOM::Parser::TML');

sub TRACE { 1 }

sub priority { return 950; }

=begin_markup TML

---++ ClassMethod scan($dom)

Identify potential =%<nop>MACRO{}%= syntax in the =$dom->{input}= buffer by
tokenising it into % separated sections. The parser is a simple stack-based
parse, modified from the traditional Foswiki::_processMacros() code.

Unlike the traditional =_processMacros()= code, macros aren't actually expanded
here - that is done from a Foswiki::DOM evaluator such as Foswiki::DOM::Writer.

It's best to think of these Foswiki::DOM::Parser::Scanner parsers as working
very similarly to syntax highlighters.

However, coming up with a repeatable parser algorithm to cater to any TML
=%<nop>MACRO%= expression is almost impossible: the Foswiki::DOM we're building
expects to be invariant and context-free (given a constant TML markup as input,
the resulting DOM tree should always be the same) - but =%<nop>MACROs%= are
notoriously non-deterministic, context-sensitive things.

So, figuring out where valid macro syntax actually begins and ends is difficult.
Macros _could_ be expanded to help figure out what actually contribute to valid
macro syntax, but that result would depend on the context in which the
expansions are done.

To clarify, ordinary exploitation of inside-out, left-to-right recursive
expansion behaviour isn't a problem when an inner (nested) macro is used to
build some or all of the outer macro's arguments (i.e. anywhere within the
={...}=). The difficult is when any other part of the outer macro is built
dynamically; such as the TAGNAME and/or its argument braces ={...}=.

For example, this is a "normal" nested macro expression, easy to figure out
where macros begin_markup and end_markup:
<verbatim class="tml">%SEARCH{
    format="%INCLUDE{"MyFormat" section="some-section" foo="bar"}%"
}%</verbatim>

But the parser can't tell from the markup alone that the following expands out
as a simple =%<nop>SEARCH=:
<verbatim class="tml">   * Set FOO = SEA
%%FOO%RCH%{
    ...
}%</verbatim>

Depending on the values (which may in turn contain their own macros requiring
recursive expansion) of =%<nop>FOO%= and =%<nop>RCH%=, any of the following
text regions could contribute to active macro syntax:<verbatim class="tml">
   %FOO%
   %%FOO%
   %RCH%
   %RCH%{...}%
   %FOO%RCH%
   %%FOO%RCH%
   %%FOO%RCH%{...}%
</verbatim>

=cut

sub scan {
    my ( $class, $dom ) = @_;
    ASSERT( $dom->isa('Foswiki::DOM') ) if DEBUG;
    $dom->trace( [ "DOM INPUT: ", $dom->{input} ] ) if TRACE;

    # Assume verbatim has been removed. TODO: Consider <dirtyareas>
    my @queue = split( /(%)/, $dom->{input} );
    my @stack;
    my $stackTop = '';    # the top stack entry. Done this way instead of
         # referring to the top of the stack for efficiency. This var
         # should be considered to be $stack[$#stack]
    my $indent = 0 if TRACE;

    while ( scalar(@queue) ) {

        $class->trace( [ 'QUEUE:', @queue ] );
        my $token = shift(@queue);

        $class->trace( ' ' x $indent . "PROCESSING $token" ) if TRACE;

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {
            $class->trace( ' ' x $indent . "CONSIDER $stackTop" ) if TRACE;

            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stackTop =~ /\}$/s ) {
                while ( scalar(@stack)
                    && $stackTop !~ /^%$Foswiki::regex{tagNameRegex}\{.*\}$/so )
                {
                    my $top = $stackTop;

                    $class->trace( ' ' x $indent . "  COLLAPSE $top" ) if TRACE;
                    $stackTop = pop(@stack) . $top;
                }
            }

            # /s so you can have newlines in parameters
            if ( $stackTop =~ m/^%($Foswiki::regex{tagNameRegex})$/o ) {

                # SMELL: unchecked implicit untaint?
                my $tag = $1;

                $class->trace( ' ' x $indent . "POP-SIMPLE $tag" ) if TRACE;
                $stackTop = pop(@stack);
                $stackTop .= "%$tag%";
            }
            elsif (
                $stackTop =~ m/^%(($Foswiki::regex{tagNameRegex})\{(.*)\})$/so

                #m/^%(($Foswiki::regex{tagNameRegex})(?:\{(.*)\})?)$/so )
              )
            {
                my ( $expr, $tag, $args ) = ( $1, $2, $3 );

                $stackTop = pop(@stack);
                $stackTop .= "%$expr%";
            }
            else {
                push( @stack, $stackTop );
                $stackTop = '%';    # push a new context
                $indent += 1 if TRACE;
            }
        }
        else {
            $stackTop .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( scalar(@stack) ) {
        my $expr = $stackTop;

        $stackTop = pop(@stack);
        $stackTop .= $expr;
    }

    $class->trace("FINAL $stackTop") if TRACE;

    return $stackTop;
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
