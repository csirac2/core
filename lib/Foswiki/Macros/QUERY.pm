# See bottom of file for license and copyright information
package Foswiki;

use strict;

our $evalParser; # could share $ifParser from IF.pm

sub QUERY {
    my ( $this, $params, $topicObject ) = @_;
    my $result;
    my $expr = $params->{_DEFAULT};
    my $style = lc($params->{style} || '');

    # Recursion block.
    $this->{evaluatingEval} ||= {};

    # Block after 5 levels.
    if (   $this->{evaluatingEval}->{$expr}
        && $this->{evaluatingEval}->{$expr} > 5 )
    {
        delete $this->{evaluatingEval}->{$expr};
        return '';
    }
    unless ($evalParser) {
        require Foswiki::If::Parser;
        $evalParser = new Foswiki::If::Parser();
    }

    $this->{evaluatingEval}->{$expr}++;
    try {
        my $node = $evalParser->parse($expr);
        $result = $node->evaluate( tom => $topicObject, data => $topicObject );
        my $fn = "_serialise_$style";
        $result = $this->$fn($result);
    }
    catch Foswiki::Infix::Error with {
        my $e = shift;
        $result =
          $this->inlineAlert(
              'alerts', 'generic', 'QUERY{', $params->stringify(),
              '}:', $e->{-text} );
    }
    finally {
        delete $this->{evaluatingEval}->{$expr};
    };

    return $result;
}

sub _serialise_perl {
    my ($this, $result) = @_;
    use Data::Dumper ();
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 1;
    return Data::Dumper->Dump([$result]);
}

sub _serialise_json {
    my ($this, $result) = @_;
    use JSON ();
    return JSON::to_json($result, { allow_nonref => 1 });
}

# Default serialiser
sub _serialise_ {
    my ($this, $result) = @_;
    if (ref($result) eq 'ARRAY') {
        # If any of the results is non-scalar, have to perl it
        foreach my $v (@$result) {
            if (ref($v)) {
                return _serialise_perl($result);
            }
        }
        return join(',', @$result);
    } elsif (ref($result)) {
        return _serialise_perl($result);
    } else {
        return defined $result ? $result : '';
    }
}

1;
__DATA__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
