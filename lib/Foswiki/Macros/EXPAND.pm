# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

sub EXPAND {
    my ( $this, $params ) = @_;
    my $macro = $params->{_DEFAULT};
    return $this->inlineAlert('alerts', 'EXPAND_nomacro')
      unless $macro;
    $macro = expandStandardEscapes($macro);
    my $scope = $params->{scope};
    my $meta;
    if ($scope) {
        my ( $web, $topic ) = $this->normalizeWebTopicName(
           $this->{webName}, $scope);
        return $this->inlineAlert('alerts', 'EXPAND_noscope', $scope)
          unless $this->topicExists($web, $topic);
        $meta = new Foswiki::Meta($this, $web, $topic);
        return $this->inlineAlert('alerts', 'EXPAND_noaccess', $scope)
          unless $meta->haveAccess('VIEW');
        $this->{prefs}->popTopicContext();
        $this->{prefs}->pushTopicContext( $web, $topic );
    } else {
        $meta = new Foswiki::Meta($this, $this->{webName}, $this->{topicName});
    }
    my $expansion = $meta->expandMacros($macro);
    if ($scope) {
        $this->{prefs}->popTopicContext();
        $this->{prefs}->pushTopicContext(
            $this->{webName}, $this->{topicName} );
    }
    return $expansion;
}

1;
__END__
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
