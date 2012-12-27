# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptUrlPaths;

use strict;
use warnings;

use Foswiki::Configure qw/:cgi :auth/;

require Foswiki::Configure::Checkers::URLPATH;
our @ISA = ('Foswiki::Configure::Checkers::URLPATH');

# Type checker for entries in the {ScriptUrlPaths} hash

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref($valobj) ? $valobj->getKeys : $valobj;

    die "$keys not supported by " . __PACKAGE__ . "\n"
      unless ( $keys =~ /^\{ScriptUrlPaths\}\{(.*)\}$/ );

    # non-existent keys are treated differently from
    # null keys.  Just accept non-existent/undefined ones.

    return '' unless ( defined $Foswiki::cfg{ScriptUrlPaths}{$1} );

    my $script = $1;

    # Should be path to script

    my $e = '';

    $e = $this->SUPER::check($valobj);

    return $e if ( $e =~ /Error:/ );

    my $value = $this->getCfg;

    # Very old config; undefined implies no alias

    $value =
        $this->getCfg('{ScriptUrlPath}')
      . "/$script"
      . ( $this->getCfg('{ScriptSuffix}') || '' )
      unless ( defined $value );

    # Blank implies '/'; Display '/' rather than ''
    my $dval = ( $value || '/' );

    # Attempt access

    my $t    = "/Web/Topic/Img/$script?configurationTest=yes";
    my $ok   = $this->NOTE("Content under $dval is accessible.");
    my $fail = $this->ERROR(
"Content under $dval is inaccessible.  Check the setting and webserver configuration."
    );
    $valobj->{errors}--;

    my $qkeys = $keys;
    $qkeys =~ s/([{}])/\\\\$1/g;

    $e .= $this->NOTE(
        qq{<span class="foswikiJSRequired">
<span name="${keys}Wait">Please wait while the setting is tested.  Disregard any message that appears only briefly.</span>
<span name="${keys}Ok">$ok</span>
<span name="${keys}Error">$fail</span></span>
<span class="foswikiNonJS">Content under $dval is accessible if a green check appears to the right of this text.
<img src="$value$t" style="margin-left:10px;height:15px;"
 onload='\$("[name=\\"${qkeys}Error\\"],[name=\\"${qkeys}Wait\\"]").hide().find("div.configureWarn,div.configureError").removeClass("configureWarn configureError");configure.toggleExpertsMode("");\$("[name=\\"${qkeys}Ok\\"]").show();'
 onerror='\$("[name=\\"${qkeys}Ok\\"],[name=\\"${qkeys}Wait\\"]").hide();\$("[name=\\"${qkeys}Error\\"]").show();'><br >If it does not appear, check the setting and webserver configuration.</span>}
    );
    $this->{JSContent} = 1;

    return $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    my $keys = ref $valobj ? $valobj->getKeys : $valobj;

    my $e = '';

    my $r;

    ( $e, $r ) = $this->SUPER::provideFeedback(@_);

    if ( $button == 2 ) {
        require Foswiki::Net;
        my $cookie = Foswiki::newCookie($session);
        my $net    = Foswiki::Net->new;

        local $Foswiki::Net::LWPAvailable   = 0;
        local $Foswiki::Net::noHTTPResponse = 1;
        local $Foswiki::VERSION             = $Foswiki::VERSION || '0.0';

        my $test   = '/Web/Topic/Env/Echo?configurationTest=yes';
        my $target = $this->getItemCurrentValue;
        $target = '$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}'
          if ( !defined $target );
        Foswiki::Configure::Load::expandValue($target);
        my $data;

        my $url = $Foswiki::cfg{DefaultUrlHost} . $target . $test;
        $e .= $this->NOTE("Tracing access to <tt>$url</tt>");

        my ( $limit, $try ) = (10);
        my @headers = ( Cookie => join( '=', $cookie->name, $cookie->value ), );

        if ( ( my $user = $query->param('{ConfigureGUI}{TestUsername}') ) ) {
            my $password = $query->param('{ConfigureGUI}{TestPassword}') || '';
            require MIME::Base64;
            my $auth = MIME::Base64::encode_base64( "$user:$password", '' );
            push @headers, Authorization => "Basic $auth";
        }

        for ( $try = 1 ; $try <= $limit ; $try++ ) {
            my $response = $net->getExternalResource( $url, @headers );
            if ( $response->is_error ) {
                my $content = $response->content || '';
                $content =~ s,<(/)?h\d+>,$1? '</b>' : '<p><b>',e;
                $e .=
                  $this->ERROR( "Failed to access $url<pre>"
                      . $response->code . ' '
                      . $response->message
                      . $content
                      . "</pre>" );
                last;
            }
            if ( $response->is_redirect ) {
                $url = $response->header('location') || '';
                $e .=
                  $this->NOTE( "Redirected ("
                      . $response->code
                      . ") to <tt>"
                      . ( $url ? "$url" : 'nowhere' )
                      . "</tt>" );
                last unless ($url);
                next;
            }
            $data = $response->content;
            unless ( $url =~ m,^(https?://([^:/]+)(:\d+)?)(/.*)?\Q$test\E$, ) {
                $e .= $this->ERROR("<tt>$url</tt> does not match request");
                last;
            }
            my ( $host, $hname, $port, $path ) = ( $1, $2, $3, $4 );
            if ( $host ne $Foswiki::cfg{DefaultUrlHost} ) {
                $e .= $this->WARN(
"<tt>$host</tt> does not match {DefaultUrlHost} (<tt>$Foswiki::cfg{DefaultUrlHost}</tt>)"
                );
            }
            $path ||= '';
            my @server = split( /\|/, $data, 3 );
            if ( @server != 3 ) {
                my $ddat = ( split( /\r?\n/, $data, 2 ) )[0] || '';
                $e .= $this->ERROR(
                    "Server returned incorrect diagnostic data:<pre>$ddat</pre>"
                );
            }
            else {
                if ( $server[0] eq $target ) {
                    $e .= $this->NOTE(
                        "Server received the expected path (<tt>$target</tt>)");
                }
                else {
                    $e .= $this->ERROR(
"Server received \"<tt>$server[0]</tt>\", but the expected path is \"<tt>$target</tt>\"<br >The correct setting for $keys is probably <tt>$server[0]</tt>"
                    );
                }
            }
            if ( $path ne $target ) {
                $e .=
                  $this->ERROR( "Path used by "
                      . ( $try > 1 ? "final " : '' )
                      . "GET (\"<tt>$path</tt>\") does not match $keys (<tt>$target</tt>)"
                  );
            }
            else {
                $e .= $this->NOTE_OK("Path \"<tt>$path</tt>\" is correct");
            }
            last;
        }
        if ( $try > $limit ) {
            $e .= $this->ERROR("Excessive redirects (>$limit) stopped trace.");
        }
    }
    return wantarray ? ( $e, $r ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
