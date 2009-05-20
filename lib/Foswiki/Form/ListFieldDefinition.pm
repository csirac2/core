# See bottom of file for license and copyright details

=begin TML

---++ package Foswiki::Form::ListFieldDefinition
Form field definitions that accept lists of values in the field definition.
This is different to being multi-valued, which means the field type
can *store* multiple values.

=cut

package Foswiki::Form::ListFieldDefinition;

use strict;
use Assert;

use Foswiki::Form::FieldDefinition ();
our @ISA = ( 'Foswiki::Form::FieldDefinition' );

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{_options};
}

# PROTECTED - parse the {value} and extract a list of options.
# Done lazily to avoid repeated topic reads.
sub getOptions {

    # $web and $topic are where the form definition lives
    my $this = shift;

    return $this->{_options} if $this->{_options};

    my @vals = ();

    @vals = split( /,/, $this->{value} );
    if ( !scalar(@vals) ) {
        my $topic = $this->{definingTopic} || $this->{name};
        my $session = $this->{session};
        my ( $fieldWeb, $fieldTopic ) =
          $session->normalizeWebTopicName( $this->{web}, $topic );
        if ( $session->topicExists( $fieldWeb, $fieldTopic ) ) {
            my $meta = Foswiki::Meta->load( $session, $fieldWeb, $fieldTopic );
            next unless $meta->haveAccess('VIEW');

            # Process SEARCHES for Lists
            my $text = $meta->expandMacros( $meta->text() );

            # SMELL: yet another table parser
            my $inBlock = 0;
            foreach ( split( /\r?\n/, $text ) ) {
                if (/^\s*\|\s*\*Name\*\s*\|/) {
                    $inBlock = 1;
                }
                elsif (/^\s*\|\s*([^|]*?)\s*\|/) {
                    push( @vals, TAINT($1) ) if ($inBlock);
                }
                else {
                    $inBlock = 0;
                }
            }
        }
    }
    @vals = map { $_ =~ s/^\s*(.*)\s*$/$1/; $_; } @vals;

    $this->{_options} = \@vals;

    return $this->{_options};
}

1;
__DATA__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

