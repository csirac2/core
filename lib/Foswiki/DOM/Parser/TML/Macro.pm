# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Parser::TML::Macro

=cut

package Foswiki::DOM::Parser::TML::Macro;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Parser::TML();
our @ISA = ('Foswiki::DOM::Parser::TML');

sub TRACE { 1 }

sub priority { return 950; }

sub scan {
    my ( $class, $dom ) = @_;
    my %state;
    ASSERT( $dom->isa('Foswiki::DOM') ) if DEBUG;

    $dom->trace( [ "DOM INPUT: ", $dom->{input} ] ) if TRACE;
    ASSERT( length( $dom->{input} ) == $input_length ) if DEBUG;

    return;
}

=begin TML

---++ PRIVATE ClassMethod _process($dom, $tagf, $depth)

Process Foswiki %TAGS{}% by parsing the input tokenised into
% separated sections. The parser is a simple stack-based parse,
sufficient to ensure nesting of tags is correct, but no more
than that.

$depth limits the number of recursive expansion steps that
can be performed on expanded tags.

=cut

sub _process {
    my ( $class, $dom, $text, $tagf, $depth ) = @_;
    my $indentlevel = 0;

    unless ($depth) {
        $class->warn("Max recursive depth reached: $text");

        # prevent recursive expansion that just has been detected
        # from happening in the error message
        $text =~ s/%(.*?)%/$1/go;
        return $text;
    }

    # Assume dirtyareas & verbatim have been removed
    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = '';    # the top stack entry. Done this way instead of
         # referring to the top of the stack for efficiency. This var
         # should be considered to be $stack[$#stack]

    while ( scalar(@queue) ) {

        #print STDERR "QUEUE:".join("\n      ", map { "'$_'" } @queue)."\n";
        my $token = shift(@queue);

        #print STDERR ' ' x $indentlevel,"PROCESSING $token \n";

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {

            #print STDERR ' ' x $indentlevel,"CONSIDER $stackTop\n";
            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stackTop =~ /}$/s ) {
                while ( scalar(@stack)
                    && $stackTop !~ /^%$regex{tagNameRegex}\{.*}$/so )
                {
                    my $top = $stackTop;

                    #print STDERR ' ' x $indentlevel,"COLLAPSE $top \n";
                    $stackTop = pop(@stack) . $top;
                }
            }

            # /s so you can have newlines in parameters
            if ( $stackTop =~ m/^%(($regex{tagNameRegex})(?:{(.*)})?)$/so ) {

                # SMELL: unchecked implicit untaint?
                my ( $expr, $tag, $args ) = ( $1, $2, $3 );

                #print STDERR ' ' x $indentlevel,"POP $tag\n";
                #Monitor::MARK("Before $tag");
                my $e = &$tagf( $this, $tag, $args, $topicObject );

                #Monitor::MARK("After $tag");

                if ( defined($e) ) {

                    #print STDERR ' ' x $indentlevel--,"EXPANDED $tag -> $e\n";
                    $stackTop = pop(@stack);

                    # Don't bother recursively expanding unless there are
                    # unexpanded tags in the result.
                    unless ( $e =~ /%$regex{tagNameRegex}(?:{.*})?%/so ) {
                        $stackTop .= $e;
                        next;
                    }

                    # Recursively expand tags in the expansion of $tag
                    $stackTop .=
                      $this->_processMacros( $e, $tagf, $topicObject,
                        $depth - 1 );
                }
                else {

                    #print STDERR ' ' x $indentlevel++,"EXPAND $tag FAILED\n";
                    # To handle %NOP
                    # correctly, we have to handle the %VAR% case differently
                    # to the %VAR{}% case when a variable expansion fails.
                    # This is so that recursively define variables e.g.
                    # %A%B%D% expand correctly, but at the same time we ensure
                    # that a mismatched }% can't accidentally close a context
                    # that was left open when a tag expansion failed.
                    # However TWiki didn't do this, so for compatibility
                    # we have to accept that %NOP can never be fixed. if it
                    # could, then we could uncomment the following:

                    #if( $stackTop =~ /}$/ ) {
                    #    # %VAR{...}% case
                    #    # We need to push the unexpanded expression back
                    #    # onto the stack, but we don't want it to match the
                    #    # tag expression again. So we protect the %'s
                    #    $stackTop = "&#37;$expr&#37;";
                    #} else
                    #{

                    # %VAR% case.
                    # In this case we *do* want to match the tag expression
                    # again, as an embedded %VAR% may have expanded to
                    # create a valid outer expression. This is directly
                    # at odds with the %VAR{...}% case.
                    push( @stack, $stackTop );
                    $stackTop = '%';    # open new context
                                        #}
                }
            }
            else {
                push( @stack, $stackTop );
                $stackTop = '%';        # push a new context
                                        #$indentlevel++;
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

    #print STDERR "FINAL $stackTop\n";

    return $stackTop;
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
                    node_class => 'Foswiki::DOM::Node::Macro',
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
                node_class => 'Foswiki::DOM::Node::Macro',
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
