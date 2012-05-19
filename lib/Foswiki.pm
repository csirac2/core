# See bottom of file for license and copyright information
package Foswiki;

=begin TML

---+ package Foswiki

Foswiki operates by creating a singleton object (known as the Session
object) that acts as a point of reference for all the different
modules in the system. This package is the class for this singleton,
and also contains the vast bulk of the basic constants and the per-
site configuration mechanisms.

Global variables are avoided wherever possible to avoid problems
with CGI accelerators such as mod_perl.

---++ Public Data members
   * =request=          Pointer to the Foswiki::Request
   * =response=         Pointer to the Foswiki::Response
   * =context=          Hash of context ids
   * =plugins=          Foswiki::Plugins singleton
   * =prefs=            Foswiki::Prefs singleton
   * =remoteUser=       Login ID when using ApacheLogin. Maintained for
                        compatibility only, do not use.
   * =requestedWebName= Name of web found in URL path or =web= URL parameter
   * =scriptUrlPath=    URL path to the current script. May be dynamically
                        extracted from the URL path if {GetScriptUrlFromCgi}.
                        Only required to support {GetScriptUrlFromCgi} and
                        not consistently used. Avoid.
   * =access=         Foswiki::Access singleton
   * =store=            Foswiki::Store singleton
   * =topicName=        Name of topic found in URL path or =topic= URL
                        parameter
   * =urlHost=          Host part of the URL (including the protocol)
                        determined during intialisation and defaulting to
                        {DefaultUrlHost}
   * =user=             Unique user ID of logged-in user
   * =users=            Foswiki::Users singleton
   * =webName=          Name of web found in URL path, or =web= URL parameter,
                        or {UsersWebName}

=cut

use strict;
use warnings;
use Assert;
use Error qw( :try );
use Monitor                  ();
use CGI                      ();  # Always required to get html generation tags;
use Digest::MD5              ();  # For passthru and validation
use Foswiki::Configure::Load ();

use 5.006;         # First version to accept v-numbers.
require v5.8.8;    # see http://foswiki.org/Development/RequirePerl588

# Site configuration constants
our %cfg;

# Other computed constants
our $foswikiLibDir;
our %regex;
our %macros;
our %contextFreeSyntax;
our $VERSION;
our $RELEASE;
our $TRUE  = 1;
our $FALSE = 0;
our $engine;
our $TranslationToken = "\0";    # Do not deprecate - used in many plugins

# Note: the following marker is used in text to mark RENDERZONE
# macros that have been hoisted from the source text of a page. It is
# carefully chosen so that it is (1) not normally present in written
# text (2) does not combine with other characters to form valid
# wide-byte characters and (3) does not conflict with other markers used
# by Foswiki/Render.pm
our $RENDERZONE_MARKER = "\3";

# Used by takeOut/putBack blocks
our $BLOCKID = 0;
our $OC      = "<!--\0";
our $CC      = "\0-->";

# This variable is set if Foswiki is running in unit test mode.
# It is provided so that modules can detect unit test mode to avoid
# corrupting data spaces.
our $inUnitTestMode = 0;

sub SINGLE_SINGLETONS       { 0 }
sub SINGLE_SINGLETONS_TRACE { 0 }

# Returns the full path of the directory containing Foswiki.pm
sub _getLibDir {
    return $foswikiLibDir if $foswikiLibDir;

    $foswikiLibDir = $INC{'Foswiki.pm'};

    # fix path relative to location of called script
    if ( $foswikiLibDir =~ /^\./ ) {
        print STDERR
"WARNING: Foswiki lib path $foswikiLibDir is relative; you should make it absolute, otherwise some scripts may not run from the command line.";
        my $bin;

        # SMELL : Should not assume environment variables; get data from request
        if (   $ENV{SCRIPT_FILENAME}
            && $ENV{SCRIPT_FILENAME} =~ m#^(.+)/.+?$# )
        {

            # CGI script name
            # implicit untaint OK, because of use of $SCRIPT_FILENAME
            $bin = $1;
        }
        elsif ( $0 =~ m#^(.*)/.*?$# ) {

            # program name
            # implicit untaint OK, because of use of $PROGRAM_NAME ($0)
            $bin = $1;
        }
        else {

            # last ditch; relative to current directory.
            require Cwd;
            $bin = Cwd::cwd();
        }
        $foswikiLibDir = "$bin/$foswikiLibDir/";

        # normalize "/../" and "/./"
        while ( $foswikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1| ) {
        }
        $foswikiLibDir =~ s|([\\/])\.[\\/]|$1|g;
    }
    $foswikiLibDir =~ s|([\\/])[\\/]*|$1|g;    # reduce "//" to "/"
    $foswikiLibDir =~ s|[\\/]$||;              # cut trailing "/"

    return $foswikiLibDir;
}

BEGIN {

    #Monitor::MARK("Start of BEGIN block in Foswiki.pm");
    if (DEBUG) {
        if ( not $Assert::soft ) {

            # If ASSERTs are on (and not soft), then warnings are errors.
            # Paranoid, but the only way to be sure we eliminate them all.
            # Look out also for $cfg{WarningsAreErrors}, below, which
            # is another way to install this handler without enabling
            # ASSERTs
            # ASSERTS are turned on by defining the environment variable
            # FOSWIKI_ASSERTS. If ASSERTs are off, this is assumed to be a
            # production environment, and no stack traces or paths are
            # output to the browser.
            $SIG{'__WARN__'} = sub { die @_ };
            $Error::Debug = 1;    # verbose stack traces, please
        }
        else {

            # ASSERTs are soft, so warnings are not errors
            # but ASSERTs are enabled. This is useful for tracking down
            # problems that only manifest on production servers.
            # Consequently, this is only useful when
            # $cfg{WarningsAreErrors} is NOT enabled
            $Error::Debug = 0;    # no verbose stack traces
        }
    }
    else {
        $Error::Debug = 0;        # no verbose stack traces
    }

    # DO NOT CHANGE THE FORMAT OF $VERSION
    # Automatically expanded on checkin of this module
    $VERSION = '$Date$ $Rev$ ';
    $RELEASE = 'Foswiki-1.2.0-alpha';
    $VERSION =~ s/^.*?\((.*)\).*: (\d+) .*?$/$RELEASE, $1, build $2/;

    # Default handlers for different %TAGS%
    # Where an entry is set as 'undef', the tag will be demand-loaded
    # from Foswiki::Macros, if it is used. This tactic is used to reduce
    # the load time of this module, especially when it is used from
    # REST handlers.
    %macros = (
        ADDTOHEAD => undef,

        # deprecated, use ADDTOZONE instead
        ADDTOZONE    => undef,
        ALLVARIABLES => sub { $_[0]->{prefs}->stringify() },
        ATTACHURL =>
          sub { return $_[0]->getPubUrl( 1, $_[2]->web, $_[2]->topic ); },
        ATTACHURLPATH =>
          sub { return $_[0]->getPubUrl( 0, $_[2]->web, $_[2]->topic ); },
        DATE => sub {
            Foswiki::Time::formatTime(
                time(),
                $Foswiki::cfg{DefaultDateFormat},
                $Foswiki::cfg{DisplayTimeValues}
            );
        },
        DISPLAYTIME => sub {
            Foswiki::Time::formatTime(
                time(),
                $_[1]->{_DEFAULT} || '',
                $Foswiki::cfg{DisplayTimeValues}
            );
        },
        ENCODE    => undef,
        ENV       => undef,
        EXPAND    => undef,
        FORMAT    => undef,
        FORMFIELD => undef,
        GMTIME    => sub {
            Foswiki::Time::formatTime( time(), $_[1]->{_DEFAULT} || '',
                'gmtime' );
        },
        GROUPINFO => undef,
        GROUPS    => undef,
        HTTP_HOST =>

          #deprecated functionality, now implemented using %ENV%
          sub { $_[0]->{request}->header('Host') || '' },
        HTTP         => undef,
        HTTPS        => undef,
        ICON         => undef,
        ICONURL      => undef,
        ICONURLPATH  => undef,
        IF           => undef,
        INCLUDE      => undef,
        INTURLENCODE => undef,
        LANGUAGE     => sub { $_[0]->i18n->language(); },
        LANGUAGES    => undef,
        MAKETEXT     => undef,
        META         => undef,                              # deprecated
        METASEARCH   => undef,                              # deprecated
        NOP =>

          # Remove NOP tag in template topics but show content.
          # Used in template _topics_ (not templates, per se, but
          # topics used as templates for new topics)
          sub { $_[1]->{_RAW} ? $_[1]->{_RAW} : '<nop>' },
        PLUGINVERSION => sub {
            $_[0]->{plugins}->getPluginVersion( $_[1]->{_DEFAULT} );
        },
        PUBURL            => sub { $_[0]->getPubUrl(1) },
        PUBURLPATH        => sub { $_[0]->getPubUrl(0) },
        QUERY             => undef,
        QUERYPARAMS       => undef,
        QUERYSTRING       => sub { $_[0]->{request}->queryString() },
        RELATIVETOPICPATH => undef,
        REMOTE_ADDR =>

          # DEPRECATED, now implemented using %ENV%
          #move to compatibility plugin in Foswiki 2.0
          sub { $_[0]->{request}->remoteAddress() || ''; },
        REMOTE_PORT =>

          # DEPRECATED
          # CGI/1.1 (RFC 3875) doesn't specify REMOTE_PORT,
          # but some webservers implement it. However, since
          # it's not RFC compliant, Foswiki should not rely on
          # it. So we get more portability.
          sub { '' },
        REMOTE_USER =>

          # DEPRECATED
          sub { $_[0]->{request}->remoteUser() || '' },
        RENDERZONE => undef,
        REVINFO    => undef,
        REVTITLE   => undef,
        REVARG     => undef,
        SCRIPTNAME => sub { $_[0]->{request}->action() },
        SCRIPTURL  => sub { $_[0]->getScriptUrl( 1, $_[1]->{_DEFAULT} || '' ) },
        SCRIPTURLPATH =>
          sub { $_[0]->getScriptUrl( 0, $_[1]->{_DEFAULT} || '' ) },
        SEARCH => undef,
        SEP =>

          # Shortcut to %TMPL:P{"sep"}%
          sub { $_[0]->templates->expandTemplate('sep') },
        SERVERTIME => sub {
            Foswiki::Time::formatTime( time(), $_[1]->{_DEFAULT} || '',
                'servertime' );
        },
        SHOWPREFERENCE      => undef,
        SPACEDTOPIC         => undef,
        SPACEOUT            => undef,
        'TMPL:P'            => sub { $_[0]->templates->tmplP( $_[1] ) },
        TOPICLIST           => undef,
        URLENCODE           => undef,
        URLPARAM            => undef,
        USERINFO            => undef,
        USERNAME            => undef,
        VAR                 => undef,
        WEBLIST             => undef,
        WIKINAME            => undef,
        WIKIUSERNAME        => undef,
        DISPLAYDEPENDENCIES => undef,

        # Constant tag strings _not_ dependent on config. These get nicely
        # optimised by the compiler.
        ENDSECTION   => sub { '' },
        WIKIVERSION  => sub { $VERSION },
        STARTSECTION => sub { '' },
        STARTINCLUDE => sub { '' },
        STOPINCLUDE  => sub { '' },
    );
    $contextFreeSyntax{IF} = 1;

    unless ( ( $Foswiki::cfg{DetailedOS} = $^O ) ) {
        require Config;
        $Foswiki::cfg{DetailedOS} = $Config::Config{'osname'};
    }
    $Foswiki::cfg{OS} = 'UNIX';
    if ( $Foswiki::cfg{DetailedOS} =~ /darwin/i ) {    # MacOS X
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /Win/i ) {
        $Foswiki::cfg{OS} = 'WINDOWS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /vms/i ) {
        $Foswiki::cfg{OS} = 'VMS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /bsdos/i ) {
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /dos/i ) {
        $Foswiki::cfg{OS} = 'DOS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /^MacOS$/i ) {    # MacOS 9 or earlier
        $Foswiki::cfg{OS} = 'MACINTOSH';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /os2/i ) {
        $Foswiki::cfg{OS} = 'OS2';
    }

    # readConfig is defined in Foswiki::Configure::Load to allow overriding it
    if ( Foswiki::Configure::Load::readConfig() ) {
        $Foswiki::cfg{isVALID} = 1;
    }

    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    # If not set, default to strikeone validation
    $Foswiki::cfg{Validation}{Method} ||= 'strikeone';
    $Foswiki::cfg{Validation}{ValidForTime} = $Foswiki::cfg{LeaseLength}
      unless defined $Foswiki::cfg{Validation}{ValidForTime};
    $Foswiki::cfg{Validation}{MaxKeys} = 1000
      unless defined $Foswiki::cfg{Validation}{MaxKeys};

    # Constant tags dependent on the config
    $macros{ALLOWLOGINNAME} =
      sub { $Foswiki::cfg{Register}{AllowLoginName} || 0 };
    $macros{AUTHREALM}      = sub { $Foswiki::cfg{AuthRealm} };
    $macros{DEFAULTURLHOST} = sub { $Foswiki::cfg{DefaultUrlHost} };
    $macros{HOMETOPIC}      = sub { $Foswiki::cfg{HomeTopicName} };
    $macros{LOCALSITEPREFS} = sub { $Foswiki::cfg{LocalSitePreferences} };
    $macros{NOFOLLOW} =
      sub { $Foswiki::cfg{NoFollow} ? 'rel=' . $Foswiki::cfg{NoFollow} : '' };
    $macros{NOTIFYTOPIC}       = sub { $Foswiki::cfg{NotifyTopicName} };
    $macros{SCRIPTSUFFIX}      = sub { $Foswiki::cfg{ScriptSuffix} };
    $macros{STATISTICSTOPIC}   = sub { $Foswiki::cfg{Stats}{TopicName} };
    $macros{SYSTEMWEB}         = sub { $Foswiki::cfg{SystemWebName} };
    $macros{TRASHWEB}          = sub { $Foswiki::cfg{TrashWebName} };
    $macros{SANDBOXWEB}        = sub { $Foswiki::cfg{SandboxWebName} };
    $macros{WIKIADMINLOGIN}    = sub { $Foswiki::cfg{AdminUserLogin} };
    $macros{USERSWEB}          = sub { $Foswiki::cfg{UsersWebName} };
    $macros{WEBPREFSTOPIC}     = sub { $Foswiki::cfg{WebPrefsTopicName} };
    $macros{WIKIPREFSTOPIC}    = sub { $Foswiki::cfg{SitePrefsTopicName} };
    $macros{WIKIUSERSTOPIC}    = sub { $Foswiki::cfg{UsersTopicName} };
    $macros{WIKIWEBMASTER}     = sub { $Foswiki::cfg{WebMasterEmail} };
    $macros{WIKIWEBMASTERNAME} = sub { $Foswiki::cfg{WebMasterName} };

    # locale setup
    #
    #
    # Note that 'use locale' must be done in BEGIN block for regexes and
    # sorting to work properly, although regexes can still work without
    # this in 'non-locale regexes' mode.

    if ( $Foswiki::cfg{UseLocale} ) {

        # Set environment variables for grep
        $ENV{LC_CTYPE} = $Foswiki::cfg{Site}{Locale};

        # Load POSIX for I18N support.
        require POSIX;
        import POSIX qw( locale_h LC_CTYPE LC_COLLATE );

       # SMELL: mod_perl compatibility note: If Foswiki is running under Apache,
       # won't this play with the Apache process's locale settings too?
       # What effects would this have?
        setlocale( &LC_CTYPE,   $Foswiki::cfg{Site}{Locale} );
        setlocale( &LC_COLLATE, $Foswiki::cfg{Site}{Locale} );
    }

    $macros{CHARSET} = sub {
        $Foswiki::cfg{Site}{CharSet};
    };

    $macros{LANG} = sub {
        $Foswiki::cfg{Site}{Locale} =~ m/^([a-z]+_[a-z]+)/i ? $1 : 'en_US';
    };

    # Set up pre-compiled regexes for use in rendering.  All regexes with
    # unchanging variables in match should use the '/o' option.
    # In the regex hash, all precompiled REs have "Regex" at the
    # end of the name. Anything else is a string, either intended
    # for use as a character class, or as a sub-expression in
    # another compiled RE.

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    if ( $] < 5.006 or not $Foswiki::cfg{Site}{LocaleRegexes} ) {

        # No locales needed/working, or Perl 5.005, so just use
        # any additional national characters defined in LocalSite.cfg
        $regex{upperAlpha} = 'A-Z' . $Foswiki::cfg{UpperNational};
        $regex{lowerAlpha} = 'a-z' . $Foswiki::cfg{LowerNational};
        $regex{numeric}    = '\d';
        $regex{mixedAlpha} = $regex{upperAlpha} . $regex{lowerAlpha};
    }
    else {

        # Perl 5.006 or higher with working locales
        $regex{upperAlpha} = '[:upper:]';
        $regex{lowerAlpha} = '[:lower:]';
        $regex{numeric}    = '[:digit:]';
        $regex{mixedAlpha} = '[:alpha:]';
    }
    $regex{mixedAlphaNum} = $regex{mixedAlpha} . $regex{numeric};
    $regex{lowerAlphaNum} = $regex{lowerAlpha} . $regex{numeric};
    $regex{upperAlphaNum} = $regex{upperAlpha} . $regex{numeric};

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/.

    $regex{linkProtocolPattern} = $Foswiki::cfg{LinkProtocolPattern};

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $regex{headerPatternDa} = qr/^---+(\++|\#+)(.*)$/m;

    # '<h6>Header</h6>
    $regex{headerPatternHt} = qr/^<h([1-6])>(.+?)<\/h\1>/mi;

    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # Foswiki concept regexes
    $regex{wikiWordRegex} = qr(
            [$regex{upperAlpha}]+
            [$regex{lowerAlphaNum}]+
            [$regex{upperAlpha}]+
            [$regex{mixedAlphaNum}]*
       )xo;
    $regex{webNameBaseRegex} =
      qr/[$regex{upperAlpha}]+[$regex{mixedAlphaNum}_]*/o;
    if ( $Foswiki::cfg{EnableHierarchicalWebs} ) {
        $regex{webNameRegex} = qr(
                $regex{webNameBaseRegex}
                (?:(?:[\.\/]$regex{webNameBaseRegex})+)*
           )xo;
    }
    else {
        $regex{webNameRegex} = $regex{webNameBaseRegex};
    }
    $regex{defaultWebNameRegex} = qr/_[$regex{mixedAlphaNum}_]+/o;
    $regex{anchorRegex}         = qr/\#[$regex{mixedAlphaNum}_]+/o;
    $regex{abbrevRegex}         = qr/[$regex{upperAlpha}]{3,}s?\b/o;

    $regex{topicNameRegex} =
      qr/(?:(?:$regex{wikiWordRegex})|(?:$regex{abbrevRegex}))/o;

    # Email regex, e.g. for WebNotify processing and email matching
    # during rendering.

    my $emailAtom = qr([A-Z0-9\Q!#\$%&'*+-/=?^_`{|}~\E])i;    # Per RFC 5322

    # Valid TLD's at http://data.iana.org/TLD/tlds-alpha-by-domain.txt
    # Version 2012022300, Last Updated Thu Feb 23 15:07:02 2012 UTC
    my $validTLD = $Foswiki::cfg{Email}{ValidTLD}
      || qr(AERO|ARPA|ASIA|BIZ|CAT|COM|COOP|EDU|GOV|INFO|INT|JOBS|MIL|MOBI|MUSEUM|NAME|NET|ORG|PRO|TEL|TRAVEL|XXX)i;

    $regex{emailAddrRegex} = qr(
       (?:                            # LEFT Side of Email address
         (?:$emailAtom+                  # Valid characters left side of email address
           (?:\.$emailAtom+)*            # And 0 or more dotted atoms
         )
       |
         (?:"[\x21\x23-\x5B\x5D-\x7E\s]+?")   # or a quoted string per RFC 5322
       )
       @
       (?:                          # RIGHT side of Email address
         (?:                           # FQDN
           [a-z0-9-]+                     # hostname part
           (?:\.[a-z0-9-]+)*              # 0 or more alphanumeric domains following a dot.
           \.(?:                          # TLD
              (?:[a-z]{2,2})                 # 2 character TLD
              |
              $validTLD                      # TLD's longer than 2 characters
           )
         )
         |
           (?:\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])      # dotted triplets IP Address
         )
       )oxi;

    # Item11185: This is how things were before we began Operation Unicode:
    #
    # $regex{filenameInvalidCharRegex} = qr/[^$regex{mixedAlphaNum}\. _-]/o;
    #
    # It was only used in Foswiki::Sandbox::sanitizeAttachmentName(), which now
    # uses $Foswiki::cfg{NameFilter} instead.
    # See RobustnessTests::test_sanitizeAttachmentName
    #
    # Actually, this is used in GenPDFPrincePlugin; let's copy NameFilter
    $regex{filenameInvalidCharRegex} = $Foswiki::cfg{NameFilter};

    # Multi-character alpha-based regexes
    $regex{mixedAlphaNumRegex} = qr/[$regex{mixedAlphaNum}]*/o;

    # %TAG% name
    $regex{tagNameRegex} =
      '[' . $regex{mixedAlpha} . '][' . $regex{mixedAlphaNum} . '_:]*';

    # Set statement in a topic
    $regex{bulletRegex} = '^(?:\t|   )+\*';
    $regex{setRegex}    = $regex{bulletRegex} . '\s+(Set|Local)\s+';
    $regex{setVarRegex} =
      $regex{setRegex} . '(' . $regex{tagNameRegex} . ')\s*=\s*(.*)$';

    # Character encoding regexes

    # 7-bit ASCII only
    $regex{validAsciiStringRegex} = qr/^[\x00-\x7F]+$/o;

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $regex{validUtf8CharRegex} = qr{
                # Single byte - ASCII
                [\x00-\x7F]
                |

                # 2 bytes
                [\xC2-\xDF][\x80-\xBF]
                |

                # 3 bytes

                    # Avoid illegal codepoints - negative lookahead
                    (?!\xEF\xBF[\xBE\xBF])

                    # Match valid codepoints
                    (?:
                    ([\xE0][\xA0-\xBF])|
                    ([\xE1-\xEC\xEE-\xEF][\x80-\xBF])|
                    ([\xED][\x80-\x9F])
                    )
                    [\x80-\xBF]
                |

                # 4 bytes
                    (?:
                    ([\xF0][\x90-\xBF])|
                    ([\xF1-\xF3][\x80-\xBF])|
                    ([\xF4][\x80-\x8F])
                    )
                    [\x80-\xBF][\x80-\xBF]
                }xo;

    $regex{validUtf8StringRegex} = qr/^(?:$regex{validUtf8CharRegex})+$/o;

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $Foswiki::cfg{ForceUnsafeRegexes} = 0
      unless defined $Foswiki::cfg{ForceUnsafeRegexes};

    # initialize lib directory early because of later 'cd's
    _getLibDir();

    # initialize the runtime engine
    if ( !defined $Foswiki::cfg{Engine} ) {

        # Caller did not define an engine; try and work it out (mainly for
        # the benefit of pre-1.0 CGI scripts)
        $Foswiki::cfg{Engine} = 'Foswiki::Engine::Legacy';
    }
    $engine = eval qq(use $Foswiki::cfg{Engine}; $Foswiki::cfg{Engine}->new);
    die $@ if $@;

    #Monitor::MARK('End of BEGIN block in Foswiki.pm');
}

# Components that all requests need
use Foswiki::Response ();
use Foswiki::Request  ();
use Foswiki::Logger   ();
use Foswiki::Meta     ();
use Foswiki::Sandbox  ();
use Foswiki::Time     ();
use Foswiki::Prefs    ();
use Foswiki::Plugins  ();
use Foswiki::Store    ();
use Foswiki::Users    ();

sub UTF82SiteCharSet {
    my ( $this, $text ) = @_;

    # Detect character encoding of the full topic name from URL
    return if ( $text =~ $regex{validAsciiStringRegex} );

    # SMELL: all this regex stuff should go away.
    # If not UTF-8 - assume in site character set, no conversion required
    if ( $^O eq 'darwin' ) {

        #this is a gross over-generalisation - as not all darwins are apple's
        # and not all darwins use apple's perl
        my $trial = $text;
        $trial =~ s/$regex{validUtf8CharRegex}//g;
        return unless ( length($trial) == 0 );
    }
    else {

        #SMELL: this seg faults on OSX leopard. (and possibly others)
        return unless ( $text =~ $regex{validUtf8StringRegex} );
    }

    # If site charset is already UTF-8, there is no need to convert anything:
    if ( $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/i ) {

        # warn if using Perl older than 5.8
        if ( $] < 5.008 ) {
            $this->logger->log( 'warning',
                    'UTF-8 not remotely supported on Perl ' 
                  . $]
                  . ' - use Perl 5.8 or higher..' );
        }

        return $text;
    }

    # Convert into ISO-8859-1 if it is the site charset.  This conversion
    # is *not valid for ISO-8859-15*.
    if ( $Foswiki::cfg{Site}{CharSet} =~ /^iso-?8859-?1$/i ) {

        # ISO-8859-1 maps onto first 256 codepoints of Unicode
        # (conversion from 'perldoc perluniintro')
        $text =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) /
          chr( ord($1) << 6 & 0xC0 | ord($2) & 0x3F )
            /egx;
    }
    else {

        # Convert from UTF-8 into some other site charset
        if ( $] >= 5.008 ) {
            require Encode;
            import Encode qw(:fallbacks);

            # Map $Foswiki::cfg{Site}{CharSet} into real encoding name
            my $charEncoding =
              Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} );
            if ( not $charEncoding ) {
                $this->logger->log( 'warning',
                        'Conversion to "'
                      . $Foswiki::cfg{Site}{CharSet}
                      . '" not supported, or name not recognised - check '
                      . '"perldoc Encode::Supported"' );
            }
            else {

                # Convert text using Encode:
                # - first, convert from UTF8 bytes into internal
                # (UTF-8) characters
                $text = Encode::decode( 'utf8', $text );

                # - then convert into site charset from internal UTF-8,
                # inserting \x{NNNN} for characters that can't be converted
                $text = Encode::encode( $charEncoding, $text, &FB_PERLQQ() );
            }
        }
        else {
            require Unicode::MapUTF8;    # Pre-5.8 Perl versions
            my $charEncoding = $Foswiki::cfg{Site}{CharSet};
            if ( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                $this->logger->log( 'warning',
                        'Conversion to "'
                      . $Foswiki::cfg{Site}{CharSet}
                      . '" not supported, or name not recognised - check '
                      . '"perldoc Unicode::MapUTF8"' );
            }
            else {

                # Convert text
                $text = Unicode::MapUTF8::from_utf8(
                    {
                        -string  => $text,
                        -charset => $charEncoding
                    }
                );

                # FIXME: Check for failed conversion?
            }
        }
    }
    return $text;
}

=begin TML

---++ ObjectMethod writeCompletePage( $text, $pageType, $contentType )

Write a complete HTML page with basic header to the browser.
   * =$text= is the text of the page script (&lt;html&gt; to &lt;/html&gt; if it's HTML)
   * =$pageType= - May be "edit", which will cause headers to be generated that force
     caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused
     data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html

This method removes noautolink and nop tags before outputting the page unless
$contentType is text/plain.

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;
    $contentType ||= 'text/html';

    my $cgis = $this->getCGISession();
    if (   $cgis
        && $contentType eq 'text/html'
        && $Foswiki::cfg{Validation}{Method} ne 'none' )
    {

        # Don't expire the validation key through login, or when
        # endpoint is an error.
        Foswiki::Validation::expireValidationKeys($cgis)
          unless ( $this->{request}->action() eq 'login'
            or ( $ENV{REDIRECT_STATUS} || 0 ) >= 400 );

        my $usingStrikeOne = 0;
        if (
            $Foswiki::cfg{Validation}{Method} eq 'strikeone'

            # Add the onsubmit handler to the form
            && $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
                Foswiki::Validation::addOnSubmit($1)/gei
          )
        {

            # At least one form has been touched; add the validation
            # cookie
            my $valCookie = Foswiki::Validation::getCookie($cgis);
            $valCookie->secure( $this->{request}->secure );
            $this->{response}
              ->cookies( [ $this->{response}->cookies, $valCookie ] );

            # Add the JS module to the page. Note that this is *not*
            # incorporated into the foswikilib.js because that module
            # is conditionally loaded under the control of the
            # templates, and we have to be *sure* it gets loaded.
            my $src = $this->{prefs}->getPreference('FWSRC') || '';
            $this->addToZone( 'script', 'JavascriptFiles/strikeone', <<JS );
<script type="text/javascript" src="$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}/JavascriptFiles/strikeone$src.js"></script>
JS
            $usingStrikeOne = 1;
        }

        # Inject validation key in HTML forms
        my $context =
          $this->{request}->url( -full => 1, -path => 1, -query => 1 ) . time();
        $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
          $1 . Foswiki::Validation::addValidationKey(
              $cgis, $context, $usingStrikeOne )/gei;
    }

    if ( $contentType ne 'text/plain' ) {

        $text = $this->_renderZones($text);
    }

    # SMELL: can't compute; faking content-type for backwards compatibility;
    # any other information might become bogus later anyway
    # Validate format of content-type (defined in rfc2616)
    my $tch = qr/[^\[\]()<>@,;:\\"\/?={}\s]/o;
    if ( $contentType =~ /($tch+\/$tch+(\s*;\s*$tch+=($tch+|"[^"]*"))*)$/oi ) {
        $contentType = $1;
    }
    else {
        $contentType = "text/plain;contenttype=invalid";
    }
    my $hdr = "Content-type: " . $1 . "\r\n";

    # Call final handler
    $this->{plugins}->dispatch( 'completePageHandler', $text, $hdr );

    # cache final page, but only view
    my $cachedPage;
    if ( $contentType ne 'text/plain' ) {
        if ( $Foswiki::cfg{Cache}{Enabled}
            && ( $this->inContext('view') || $this->inContext('rest') ) )
        {
            $cachedPage = $this->{cache}->cachePage( $contentType, $text );
            $this->{cache}->renderDirtyAreas( \$text )
              if $cachedPage && $cachedPage->{isdirty};
        }
        else {

            # remove <dirtyarea> tags
            $text =~ s/<\/?dirtyarea[^>]*>//go;
        }

        # Remove <nop> and <noautolink> tags
        $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

        # Check that the templates specified clean HTML
        if (DEBUG) {

            # When tracing is enabled in Foswiki::Templates, then there will
            # always be a <!--bodyend--> after </html>. So we need to disable
            # this check.
            require Foswiki::Templates;
            if (   !Foswiki::Templates->TRACE
                && $contentType =~ m#text/html#
                && $text =~ m#</html>(.*?\S.*)$#s )
            {
                ASSERT( 0, <<BOGUS );
Junk after </html>: $1. Templates may be bogus
- Check for excess blank lines at ends of .tmpl files
-  or newlines after %TMPL:INCLUDE
- You can enable TRACE in Foswiki::Templates to help debug
BOGUS
            }
        }
    }

    $this->{response}->pushHeader( 'X-Foswiki-Monitor-renderTime',
        $this->{request}->getTime() );

    $this->generateHTTPHeaders( $pageType, $contentType, $text, $cachedPage );

    # SMELL: null operation. the http headers are written out
    # during Foswiki::Engine::finalize
    # $hdr = $this->{response}->printHeaders;

    $this->{response}->print($text);
}

=begin TML

---++ ObjectMethod generateHTTPHeaders( $pageType, $contentType, $text, $cachedPage )

All parameters are optional.

   * =$pageType= - May be "edit", which will cause headers to be generated that force caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html
   * =$text= - page content
   * =$cachedPage= - a pointer to the page container as fetched from the page cache

=cut

sub generateHTTPHeaders {
    my ( $this, $pageType, $contentType, $text, $cachedPage ) = @_;

    my $hopts = {};

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    if ( $pageType && $pageType eq 'edit' ) {

        # Get time now in HTTP header format
        my $lastModifiedString =
          Foswiki::Time::formatTime( time, '$http', 'gmtime' );

        # Expiry time is set high to avoid any data loss.  Each instance of
        # Edit page has a unique URL with time-string suffix (fix for
        # RefreshEditPage), so this long expiry time simply means that the
        # browser Back button always works.  The next Edit on this page
        # will use another URL and therefore won't use any cached
        # version of this Edit page.
        my $expireHours   = 24;
        my $expireSeconds = $expireHours * 60 * 60;

        # and cache control headers, to ensure edit page
        # is cached until required expiry time.
        $hopts->{'last-modified'} = $lastModifiedString;
        $hopts->{expires}         = "+${expireHours}h";
        $hopts->{'cache-control'} = "max-age=$expireSeconds";
    }

    # DEPRECATED plugins header handler. Plugins should use
    # modifyHeaderHandler instead.
    my $pluginHeaders =
      $this->{plugins}->dispatch( 'writeHeaderHandler', $this->{request} )
      || '';
    if ($pluginHeaders) {
        foreach ( split /\r?\n/, $pluginHeaders ) {

            # Implicit untaint OK; data from plugin handler
            if (m/^([\-a-z]+): (.*)$/i) {
                $hopts->{$1} = $2;
            }
        }
    }

    $contentType = 'text/html' unless $contentType;
    $contentType .= '; charset=' . $Foswiki::cfg{Site}{CharSet}
      if $contentType ne ''
          && $contentType =~ m!^text/!
          && $contentType !~ /\bcharset\b/
          && $Foswiki::cfg{Site}{CharSet};

    # use our version of the content type
    $hopts->{'Content-Type'} = $contentType;

    # New (since 1.026)
    $this->{plugins}
      ->dispatch( 'modifyHeaderHandler', $hopts, $this->{request} );

    # add http compression and conditional cache controls
    if ( !$this->inContext('command_line') && $text ) {

        if (   $Foswiki::cfg{HttpCompress}
            && $ENV{'HTTP_ACCEPT_ENCODING'}
            && $ENV{'HTTP_ACCEPT_ENCODING'} =~ /(x-gzip|gzip)/i )
        {
            my $encoding = $1;
            $hopts->{'Content-Encoding'} = $encoding;
            $hopts->{'Vary'}             = 'Accept-Encoding';

            # check if we take the version from the cache
            if ( $cachedPage && !$cachedPage->{isdirty} ) {
                $text = $cachedPage->{data};
            }
            else {
                require Compress::Zlib;
                $text = Compress::Zlib::memGzip($text);
            }
        }
        elsif ($cachedPage
            && !$cachedPage->{isdirty}
            && $Foswiki::cfg{HttpCompress} )
        {

            # Outch, we need to uncompressed pages from cache again
            # Note, this is effort to avoid under any circumstances as
            # the page has been compressed when it has been created and now
            # is uncompressed again to get back the original. For now the
            # only know situation this can happen is for older browsers like IE6
            # which does not understand gzip'ed http encodings
            require Compress::Zlib;
            $text = Compress::Zlib::memGunzip($text);
        }

        # we need to force the browser into a check on every
        # request; let the server decide on an 304 as below
        $hopts->{'Cache-Control'} = 'max-age=0';

        # check etag and last modification time
        # if we have a cached page on the server side
        if ($cachedPage) {
            my $etag         = $cachedPage->{etag};
            my $lastModified = $cachedPage->{lastmodified};

            $hopts->{'ETag'}          = $etag         if $etag;
            $hopts->{'Last-Modified'} = $lastModified if $lastModified;

            # only send a 304 if both criteria are true
            my $etagFlag         = 1;
            my $lastModifiedFlag = 1;

            # check etag
            unless ( $ENV{'HTTP_IF_NONE_MATCH'}
                && $etag eq $ENV{'HTTP_IF_NONE_MATCH'} )
            {
                $etagFlag = 0;
            }

            # check last-modified
            unless ( $ENV{'HTTP_IF_MODIFIED_SINCE'}
                && $lastModified eq $ENV{'HTTP_IF_MODIFIED_SINCE'} )
            {
                $lastModifiedFlag = 0;
            }

            # finally decide on a 304 reply
            if ( $etagFlag && $lastModified ) {
                $hopts->{'Status'} = '304 Not Modified';
                $text = '';

                #print STDERR "NOT modified\n";
            }
        }

        # write back to text
        $_[3] = $text;
    }

    $hopts->{"X-FoswikiAction"} = $this->{request}->action;
    $hopts->{"X-FoswikiURI"}    = $this->{request}->uri;

    # The headers method resets all headers to what we pass
    # what we want is simply ensure our headers are there
    $this->{response}->setDefaultHeaders($hopts);
}

# Tests if the $redirect is an external URL, returning false if
# AllowRedirectUrl is denied
sub _isRedirectSafe {
    my $redirect = shift;

    return 1 if ( $Foswiki::cfg{AllowRedirectUrl} );
    return 1 if $redirect =~ m#^/#;    # relative URL - OK

    #TODO: this should really use URI
    # Compare protocol, host name and port number
    if ( $redirect =~ m!^(.*?://[^/?#]*)! ) {

        # implicit untaints OK because result not used. uc retaints
        # if use locale anyway.
        my $target = uc($1);

        $Foswiki::cfg{DefaultUrlHost} =~ m!^(.*?://[^/]*)!;
        return 1 if ( $target eq uc($1) );

        if ( $Foswiki::cfg{PermittedRedirectHostUrls} ) {
            foreach my $red (
                split( /\s*,\s*/, $Foswiki::cfg{PermittedRedirectHostUrls} ) )
            {
                $red =~ m!^(.*?://[^/]*)!;
                return 1 if ( $target eq uc($1) );
            }
        }
    }
    return 0;
}

=begin TML

---++ ObjectMethod redirectto($url) -> $url

If the CGI parameter 'redirectto' is present on the query, then will validate
that it is a legal redirection target (url or topic name). If 'redirectto'
is not present on the query, performs the same steps on $url.

Returns undef if the target is not valid, and the target URL otherwise.

=cut

sub redirectto {
    my ( $this, $url ) = @_;

    my $redirecturl = $this->{request}->param('redirectto');
    $redirecturl = $url unless $redirecturl;

    return unless $redirecturl;

    if ( $redirecturl =~ m#^$regex{linkProtocolPattern}://#o ) {

        # assuming URL
        return $redirecturl if _isRedirectSafe($redirecturl);
        return;
    }

    # assuming 'web.topic' or 'topic'
    my ( $w, $t ) =
      $this->normalizeWebTopicName( $this->{webName}, $redirecturl );

    # capture anchor
    my ( $topic, $anchor ) = split( '#', $t, 2 );
    $t = $topic if $topic;
    my @attrs = ();
    push( @attrs, '#' => $anchor ) if $anchor;

    return $this->getScriptUrl( 0, 'view', $w, $t, @attrs );
}

=begin TML

---++ StaticMethod splitAnchorFromUrl( $url ) -> ( $url, $anchor )

Takes a full url (including possible query string) and splits off the anchor.
The anchor includes the # sign. Returns an empty string if not found in the url.

=cut

sub splitAnchorFromUrl {
    my ($url) = @_;

    ( $url, my $anchor ) = $url =~ m/^(.*?)(#(.*?))*$/;
    return ( $url, $anchor );
}

=begin TML

---++ ObjectMethod redirect( $url, $passthrough, $status )

   * $url - url or topic to redirect to
   * $passthrough - (optional) parameter to pass through current query
     parameters (see below)
   * $status - HTTP status code (30x) to redirect with. Defaults to 302.

Redirects the request to =$url=, *unless*
   1 It is overridden by a plugin declaring a =redirectCgiQueryHandler=
     (a dangerous, deprecated handler!)
   1 =$session->{request}= is =undef=
Thus a redirect is only generated when in a CGI context.

Normally this method will ignore parameters to the current query. Sometimes,
for example when redirecting to a login page during authentication (and then
again from the login page to the original requested URL), you want to make
sure all parameters are passed on, and for this $passthrough should be set to
true. In this case it will pass all parameters that were passed to the
current query on to the redirect target. If the request_method for the
current query was GET, then all parameters will be passed by encoding them
in the URL (after ?). If the request_method was POST, then there is a risk the
URL would be too big for the receiver, so it caches the form data and passes
over a cache reference in the redirect GET.

NOTE: Passthrough is only meaningful if the redirect target is on the same
server.

=cut

sub redirect {
    my ( $this, $url, $passthru, $status ) = @_;
    ASSERT( defined $url ) if DEBUG;

    return unless $this->{request};

    ( $url, my $anchor ) = splitAnchorFromUrl($url);

    if ( $passthru && defined $this->{request}->method() ) {
        my $existing = '';
        if ( $url =~ s/\?(.*)$// ) {
            $existing = $1;    # implicit untaint OK; recombined later
        }
        if ( uc( $this->{request}->method() ) eq 'POST' ) {

            # Redirecting from a post to a get
            my $cache = $this->cacheQuery();
            if ($cache) {
                if ( $url eq '/' ) {
                    $url = $this->getScriptUrl( 1, 'view' );
                }
                $url .= $cache;
            }
        }
        else {

            # Redirecting a get to a get; no need to use passthru
            if ( $this->{request}->query_string() ) {
                $url .= '?' . $this->{request}->query_string();
            }
            if ($existing) {
                if ( $url =~ /\?/ ) {
                    $url .= ';';
                }
                else {
                    $url .= '?';
                }
                $url .= $existing;
            }
        }
    }

    # prevent phishing by only allowing redirect to configured host
    # do this check as late as possible to catch _any_ last minute hacks
    # TODO: this should really use URI
    if ( !_isRedirectSafe($url) ) {

        # goto oops if URL is trying to take us somewhere dangerous
        $url = $this->getScriptUrl(
            1, 'oops',
            $this->{webName}   || $Foswiki::cfg{UsersWebName},
            $this->{topicName} || $Foswiki::cfg{HomeTopicName},
            template => 'oopsredirectdenied',
            def      => 'redirect_denied',
            param1   => "$url",
            param2   => "$Foswiki::cfg{DefaultUrlHost}",
        );
    }

    $url .= $anchor if $anchor;

    # Dangerous, deprecated handler! Might work, probably won't.
    return
      if ( $this->{plugins}
        ->dispatch( 'redirectCgiQueryHandler', $this->{response}, $url ) );

    $url = $this->getLoginManager()->rewriteRedirectUrl($url);

    # Foswiki::Response::redirect doesn't automatically pass on the cookies
    # for us, so we have to do it explicitly; otherwise the session cookie
    # won't get passed on.
    $this->{response}->redirect(
        -url     => $url,
        -cookies => $this->{response}->cookies(),
        -status  => $status,
    );
}

=begin TML

---++ ObjectMethod cacheQuery() -> $queryString

Caches the current query in the params cache, and returns a rewritten
query string for the cache to be picked up again on the other side of a
redirect.

We can't encode post params into a redirect, because they may exceed the
size of the GET request. So we cache the params, and reload them when the
redirect target is reached.

=cut

sub cacheQuery {
    my $this  = shift;
    my $query = $this->{request};

    return '' unless ( scalar( $query->param() ) );

    # Don't double-cache
    return '' if ( $query->param('foswiki_redirect_cache') );

    require Foswiki::Request::Cache;
    my $uid = Foswiki::Request::Cache->new()->save($query);
    if ( $Foswiki::cfg{UsePathForRedirectCache} ) {
        return '/foswiki_redirect_cache/' . $uid;
    }
    else {
        return '?foswiki_redirect_cache=' . $uid;
    }
}

=begin TML

---++ ObjectMethod getCGISession() -> $cgisession

Get the CGI::Session object associated with this session, if there is
one. May return undef.

=cut

sub getCGISession {
    $_[0]->{users}->getCGISession();
}

=begin TML

---++ ObjectMethod getLoginManager() -> $loginManager

Get the Foswiki::LoginManager object associated with this session, if there is
one. May return undef.

=cut

sub getLoginManager {
    $_[0]->{users}->getLoginManager();
}

=begin TML

---++ StaticMethod isValidWikiWord( $name ) -> $boolean

Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my $name = shift || '';
    return ( $name =~ m/^$regex{wikiWordRegex}$/o );
}

=begin TML

---++ StaticMethod isValidTopicName( $name [, $nonww] ) -> $boolean

Check for a valid topic =$name=. If =$nonww=, then accept non wiki-words
(though they must still be composed of only valid, unfiltered characters)

=cut

# Note: must work on tainted names.
sub isValidTopicName {
    my ( $name, $nonww ) = @_;

    return 0 unless defined $name && $name ne '';
    return 1 if ( $name =~ m/^$regex{topicNameRegex}$/o );
    return 0 unless $nonww;
    return 0 if $name =~ /$cfg{NameFilter}/o;
    return 1;
}

=begin TML

---++ StaticMethod isValidWebName( $name, $system ) -> $boolean

STATIC Check for a valid web name. If $system is true, then
system web names are considered valid (names starting with _)
otherwise only user web names are valid

If $Foswiki::cfg{EnableHierarchicalWebs} is off, it will also return false
when a nested web name is passed to it.

=cut

# Note: must work on tainted names.
sub isValidWebName {
    my $name = shift || '';
    my $sys = shift;
    return 1 if ( $sys && $name =~ m/^$regex{defaultWebNameRegex}$/o );
    return ( $name =~ m/^$regex{webNameRegex}$/o );
}

=begin TML

---++ StaticMethod isValidEmailAddress( $name ) -> $boolean

STATIC Check for a valid email address name.

=cut

# Note: must work on tainted names.
sub isValidEmailAddress {
    my $name = shift || '';
    return $name =~ /^$regex{emailAddrRegex}$/o;
}

=begin TML

---++ ObjectMethod getSkin () -> $string

Get the currently requested skin path

=cut

sub getSkin {
    my $this = shift;

    my @skinpath;
    my $skins;

    if ( $this->{request} ) {
        $skins = $this->{request}->param('cover');
        if ( defined $skins
            && $skins =~ /([$regex{mixedAlphaNum}.,\s]+)/o )
        {

            # Implicit untaint ok - validated
            $skins = $1;
            push( @skinpath, split( /,\s]+/, $skins ) );
        }
    }

    $skins = $this->{prefs}->getPreference('COVER');
    if ( defined $skins
        && $skins =~ /([$regex{mixedAlphaNum}.,\s]+)/o )
    {

        # Implicit untaint ok - validated
        $skins = $1;
        push( @skinpath, split( /[,\s]+/, $skins ) );
    }

    $skins = $this->{request} ? $this->{request}->param('skin') : undef;
    $skins = $this->{prefs}->getPreference('SKIN') unless $skins;

    if ( defined $skins && $skins =~ /([$regex{mixedAlphaNum}.,\s]+)/o ) {

        # Implicit untaint ok - validated
        $skins = $1;
        push( @skinpath, split( /[,\s]+/, $skins ) );
    }

    return join( ',', @skinpath );
}

=begin TML

---++ ObjectMethod getScriptUrl( $absolute, $script, $web, $topic, ... ) -> $scriptURL

Returns the URL to a Foswiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/foswiki/bin/$script/$web/$topic".
   * =...= - an arbitrary number of name,value parameter pairs that will be url-encoded and added to the url. The special parameter name '#' is reserved for specifying an anchor. e.g. <tt>getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)</tt> will give <tt>.../view/x/y?a=1&b=2#XXX</tt>

If $absolute is set, generates an absolute URL. $absolute is advisory only;
Foswiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

The default script url is taken from {ScriptUrlPath}, unless there is
an exception defined for the given script in {ScriptUrlPaths}. Both
{ScriptUrlPath} and {ScriptUrlPaths} may be absolute or relative URIs. If
they are absolute, then they will always generate absolute URLs. if they
are relative, then they will be converted to absolute when required (e.g.
when running from the command line, or when generating rss). If
$script is not given, absolute URLs will always be generated.

If either the web or the topic is defined, will generate a full url (including web and topic). Otherwise will generate only up to the script name. An undefined web will default to the main web name.

=cut

sub getScriptUrl {
    my ( $this, $absolute, $script, $web, $topic, @params ) = @_;

    $absolute ||=
      (      $this->inContext('command_line')
          || $this->inContext('rss')
          || $this->inContext('absolute_urls') );

    # SMELL: topics and webs that contain spaces?

    my $url;
    if ( defined $Foswiki::cfg{ScriptUrlPaths} && $script ) {
        $url = $Foswiki::cfg{ScriptUrlPaths}{$script};
    }
    unless ( defined($url) ) {
        $url = $Foswiki::cfg{ScriptUrlPath};
        if ($script) {
            $url .= '/' unless $url =~ /\/$/;
            $url .= $script;
            if (
                rindex( $url, $Foswiki::cfg{ScriptSuffix} ) !=
                ( length($url) - length( $Foswiki::cfg{ScriptSuffix} ) ) )
            {
                $url .= $Foswiki::cfg{ScriptSuffix} if $script;
            }
        }
    }

    if ( $absolute && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->{urlHost} . $url;
    }

    if ( $web || $topic ) {
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        $url .= urlEncode( '/' . $web . '/' . $topic );

        $url .= make_params(@params);
    }

    return $url;
}

=begin TML

---++ StaticMethod make_params(...)
Generate a URL parameters string from parameters given. A parameter named '#' will
generate an anchor.

=cut

sub make_params {
    my $url = '';
    my @ps;
    my $anchor = '';
    while ( my $p = shift @_ ) {
        if ( $p eq '#' ) {
            $anchor = '#' . urlEncode( shift(@_) );
        }
        else {
            my $v = shift(@_);
            $v = '' unless defined $v;
            push( @ps, urlEncode($p) . '=' . urlEncode($v) );
        }
    }
    if ( scalar(@ps) ) {
        $url .= '?' . join( ';', @ps );
    }
    return $url . $anchor;
}

=begin TML

---++ ObjectMethod getPubUrl($absolute, $web, $topic, $attachment) -> $url

Composes a pub url. If $absolute is set, returns an absolute URL.
If $absolute is set, generates an absolute URL. $absolute is advisory only;
Foswiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

$web, $topic and $attachment are optional. A partial URL path will be
generated if one or all is not given.

=cut

sub getPubUrl {
    my ( $this, $absolute, $web, $topic, $attachment ) = @_;

    $absolute ||=
      (      $this->inContext('command_line')
          || $this->inContext('rss')
          || $this->inContext('absolute_urls') );

    my $url = '';
    $url .= $Foswiki::cfg{PubUrlPath};
    if ( $absolute && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->{urlHost} . $url;
    }
    if ( $web || $topic || $attachment ) {
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        my $path = '/' . $web . '/' . $topic;
        if ($attachment) {
            $path .= '/' . $attachment;

            # Attachments are served directly by web server, need to handle
            # URL encoding specially
            $url .= urlEncodeAttachment($path);
        }
        else {
            $url .= urlEncode($path);
        }
    }

    return $url;
}

=begin TML

---++ ObjectMethod deepWebList($filter, $web) -> @list

Deep list subwebs of the named web. $filter is a Foswiki::WebFilter
object that is used to filter the list. The listing of subwebs is
dependent on $Foswiki::cfg{EnableHierarchicalWebs} being true.

Webs are returned as absolute web pathnames.

=cut

sub deepWebList {
    my ( $this, $filter, $rootWeb ) = @_;
    my @list;
    my $webObject = new Foswiki::Meta( $this, $rootWeb );
    my $it = $webObject->eachWeb( $Foswiki::cfg{EnableHierarchicalWebs} );
    return $it->all() unless $filter;
    while ( $it->hasNext() ) {
        my $w = $rootWeb || '';
        $w .= '/' if $w;
        $w .= $it->next();
        if ( $filter->ok( $this, $w ) ) {
            push( @list, $w );
        }
    }
    return @list;
}

=begin TML

---++ ObjectMethod normalizeWebTopicName( $web, $topic ) -> ( $web, $topic )

Normalize a Web<nop>.<nop>TopicName

See =Foswiki::Func= for a full specification of the expansion (not duplicated
here)

*WARNING* if there is no web specification (in the web or topic parameters)
the web defaults to $Foswiki::cfg{UsersWebName}. If there is no topic
specification, or the topic is '0', the topic defaults to the web home topic
name.

*WARNING* if the input topic name is tainted, then the output web and
topic names will be tainted.

=cut

sub normalizeWebTopicName {
    my ( $this, $web, $topic ) = @_;

    ASSERT( defined $topic ) if DEBUG;

    if ( $topic =~ m|^(.*)[./](.*?)$| ) {
        $web   = $1;
        $topic = $2;

        if ( DEBUG && !UNTAINTED( $_[2] ) ) {

            # retaint data untainted by RE above
            $web   = TAINT($web);
            $topic = TAINT($topic);
        }
    }
    $web   ||= $cfg{UsersWebName};
    $topic ||= $cfg{HomeTopicName};

    # MAINWEB and TWIKIWEB expanded for compatibility reasons
    while (
        $web =~ s/%((MAIN|TWIKI|USERS|SYSTEM|DOC)WEB)%/
              $this->_expandMacroOnTopicRendering( $1 ) || ''/e
      )
    {
    }

    # Normalize web name to use / and not . as a subweb separator
    $web =~ s#\.#/#g;

    return ( $web, $topic );
}

=begin TML

---++ ClassMethod new( $defaultUser, $query, \%initialContext )

Constructs a new Foswiki session object. A unique session object exists for
ever transaction with Foswiki, for example every browser request, or every
script run. Session objects do not persist between mod_perl runs.

   * =$defaultUser= is the username (*not* the wikiname) of the default
     user you want to be logged-in, if none is available from a session
     or browser. Used mainly for unit tests and debugging, it is typically
     undef, in which case the default user is taken from
     $Foswiki::cfg{DefaultUserName}.
   * =$query= the Foswiki::Request query (may be undef, in which case an
     empty query is used)
   * =\%initialContext= - reference to a hash containing context
     name=value pairs to be pre-installed in the context hash. May be undef.

=cut

sub new {
    my ( $class, $defaultUser, $query, $initialContext ) = @_;

    Monitor::MARK("Static init over; make Foswiki object");
    ASSERT( !$query || UNIVERSAL::isa( $query, 'Foswiki::Request' ) )
      if DEBUG;

    # Compatibility; not used except maybe in plugins
    $Foswiki::cfg{TempfileDir} = "$Foswiki::cfg{WorkingDir}/tmp"
      unless defined( $Foswiki::cfg{TempfileDir} );
    if ( defined $Foswiki::cfg{WarningFileName}
        && $Foswiki::cfg{Log}{Implementation} eq 'Foswiki::Logger::PlainFile' )
    {

        # Admin has already expressed a preference for where they want their
        # logfiles to go, and has obviously not re-run configure yet.
        $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::Compatibility';

#print STDERR "WARNING: Foswiki is using the compatibility logger. Please re-run configure and check your logfiles settings\n";
    }
    else {

        # Otherwise make sure it is defined for use in plugins,
        # but don't overwrite the setting from configure, if there is one.
        # This is especially important when the admin has *chosen*
        # to use the compatibility logger.
        if ( not defined $Foswiki::cfg{LogFileName} ) {
            $Foswiki::cfg{LogFileName} = "$Foswiki::cfg{Log}{Dir}/events.log";
        }
    }

    # Set command_line context if there is no query
    $initialContext ||= defined($query) ? {} : { command_line => 1 };

    # This foswiki supports : paragraph indent
    $initialContext->{SUPPORTS_PARA_INDENT} = 1;

    $query ||= new Foswiki::Request();
    my $this = bless( { sandbox => 'Foswiki::Sandbox' }, $class );

    if (SINGLE_SINGLETONS_TRACE) {
        require Data::Dumper;
        print STDERR "new $this: "
          . Data::Dumper->Dump( [ [caller], [ caller(1) ] ] );
    }

    # Tell Foswiki::Response which charset we are using if not default
    $Foswiki::cfg{Site}{CharSet} ||= 'iso-8859-1';

    $this->{request}  = $query;
    $this->{cgiQuery} = $query;    # for backwards compatibility in contribs
    $this->{response} = new Foswiki::Response();
    $this->{digester} = new Digest::MD5();

    # This is required in case we get an exception during
    # initialisation, so that we have a session to handle it with.
    ASSERT( !$Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;
    $Foswiki::Plugins::SESSION = $this;
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    # hash of zone records
    $this->{_zones} = ();

    # hash of occurences of RENDERZONE
    $this->{_renderZonePlaceholder} = ();

    $this->{context} = $initialContext;

    if ( $Foswiki::cfg{Cache}{Enabled} && $Foswiki::cfg{Cache}{Implementation} )
    {
        eval "require $Foswiki::cfg{Cache}{Implementation}";
        ASSERT( !$@, $@ ) if DEBUG;
        $this->{cache} = $Foswiki::cfg{Cache}{Implementation}->new();
    }

    my $prefs = new Foswiki::Prefs($this);
    $this->{prefs}   = $prefs;
    $this->{plugins} = new Foswiki::Plugins($this);

    eval "require $Foswiki::cfg{Store}{Implementation}";
    ASSERT( !$@, $@ ) if DEBUG;
    $this->{store} = $Foswiki::cfg{Store}{Implementation}->new();

    #Monitor::MARK("Created store");

    $this->{users} = new Foswiki::Users($this);

    #Monitor::MARK("Created users object");

    #{urlHost}  is needed by loadSession..
    my $url = $query->url();
    if ( $url && $url =~ m{^([^:]*://[^/]*).*$} ) {
        $this->{urlHost} = $1;

        if ( $Foswiki::cfg{RemovePortNumber} ) {
            $this->{urlHost} =~ s/\:[0-9]+$//;
        }

        # If the urlHost in the url is localhost, this is a lot less
        # useful than the default url host. This is because new CGI("")
        # assigns this host by default - it's a default setting, used
        # when there is nothing better available.
        if ( $this->{urlHost} =~ /^(https?:\/\/)localhost$/i ) {
            my $protocol = $1;

#only replace localhost _if_ the protocol matches the one specified in the DefaultUrlHost
            if ( $Foswiki::cfg{DefaultUrlHost} =~ /^$protocol/i ) {
                $this->{urlHost} = $Foswiki::cfg{DefaultUrlHost};
            }
        }
    }
    else {
        $this->{urlHost} = $Foswiki::cfg{DefaultUrlHost};
    }
    ASSERT( $this->{urlHost} ) if DEBUG;

    # Load (or create) the CGI session
    $this->{remoteUser} = $this->{users}->loadSession($defaultUser);

    # Make %ENV safer, preventing hijack of the search path. The
    # environment is set per-query, so this can't be done in a BEGIN.
    # TWikibug:Item4382: Default $ENV{PATH} must be untainted because
    # Foswiki runs with use strict and calling external programs that
    # writes on the disk will fail unless Perl seens it as set to safe value.
    if ( $Foswiki::cfg{SafeEnvPath} ) {
        $ENV{PATH} = $Foswiki::cfg{SafeEnvPath};
    }
    else {

        # SMELL: how can we validate the PATH?
        $ENV{PATH} = Foswiki::Sandbox::untaintUnchecked( $ENV{PATH} );
    }
    delete @ENV{qw( IFS CDPATH ENV BASH_ENV )};

    if (   $Foswiki::cfg{GetScriptUrlFromCgi}
        && $url
        && $url =~ m{^[^:]*://[^/]*(.*)/.*$}
        && $1 )
    {

        # SMELL: this is a really dangerous hack. It will fail
        # spectacularly with mod_perl.
        # SMELL: why not just use $query->script_name?
        # SMELL: unchecked implicit untaint?
        $this->{scriptUrlPath} = $1;
    }

    my $web   = '';
    my $topic = $query->param('topic');
    if ($topic) {
        if (   $topic =~ m#^$regex{linkProtocolPattern}://#o
            && $this->{request} )
        {

            # SMELL: this is a result of Codev.GoBoxUnderstandsURLs,
            # an unrequested, undocumented, and AFAICT pretty useless
            #"feature". It should be deprecated (or silently removed; I
            # really, really doubt anyone is using it)
            $this->{webName} = '';
            $this->redirect($topic);
            return $this;
        }
        elsif ( $topic =~ m#^(.*)[./](.*?)$# ) {

            # is '?topic=Webname.SomeTopic'
            # implicit untaint OK - validated later
            $web   = $1;
            $topic = $2;
            $web =~ s/\./\//g;

            # jump to WebHome if 'bin/script?topic=Webname.'
            $topic = $Foswiki::cfg{HomeTopicName} if ( $web && !$topic );
        }

        # otherwise assume 'bin/script/Webname?topic=SomeTopic'
    }
    else {
        $topic = '';
    }

    my $pathInfo = $query->path_info();
    $pathInfo =~ s|//+|/|g;    # multiple //'s are illogical

    # Get the web and topic names from PATH_INFO
    if ( $pathInfo =~ m#^/(.*)[./](.*?)$# ) {

        # is '/Webname/SomeTopic' or '/Webname'
        # implicit untaint OK - validated later
        $web   = $1 unless $web;
        $topic = $2 unless $topic;
        $web =~ s/\./\//g;
    }
    elsif ( $pathInfo =~ m#^/(.*?)$# ) {

        # is 'bin/script/Webname' or 'bin/script/'
        # implicit untaint OK - validated later
        $web = $1 unless $web;
    }
    my $topicNameTemp = $this->UTF82SiteCharSet($topic);
    if ($topicNameTemp) {
        $topic = $topicNameTemp;
    }

    # Item3270 - here's the appropriate place to enforce spec
    # http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item3270
    $topic = ucfirst($topic);

    # Validate and untaint topic name from path info
    $this->{topicName} = Foswiki::Sandbox::untaint( $topic,
        \&Foswiki::Sandbox::validateTopicName );

    # Set the requestedWebName before applying defaults - used by statistics
    # generation.   Note:  This is validated using Topic name rules to permit
    # names beginning with lower case.
    $this->{requestedWebName} =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateTopicName );

    # Validate web name from path info
    $this->{webName} =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );

    if ( !defined $this->{webName} && !defined $this->{topicName} ) {
        $this->{webName}   = $Foswiki::cfg{UsersWebName};
        $this->{topicName} = $Foswiki::cfg{HomeTopicName};
    }

    $this->{webName} = ''
      unless ( defined $this->{webName} );

    $this->{topicName} = $Foswiki::cfg{HomeTopicName}
      unless ( defined $this->{topicName} );

    # Convert UTF-8 web and topic name from URL into site charset if
    # necessary
    # SMELL: merge these two cases, browsers just don't mix two encodings
    # in one URL - can also simplify into 2 lines by making function
    # return unprocessed text if no conversion
    my $webNameTemp = $this->UTF82SiteCharSet( $this->{webName} );
    if ($webNameTemp) {
        $this->{webName} = $webNameTemp;
    }

    $this->{scriptUrlPath} = $Foswiki::cfg{ScriptUrlPath};

    # Form definition cache
    $this->{forms} = {};

    # Push global preferences from %SYSTEMWEB%.DefaultPreferences
    $prefs->loadDefaultPreferences();

    #Monitor::MARK("Loaded default prefs");

    # SMELL: what happens if we move this into the Foswiki::Users::new?
    $this->{user} = $this->{users}->initialiseUser( $this->{remoteUser} );

    #Monitor::MARK("Initialised user");

    # Static session variables that can be expanded in topics when they
    # are enclosed in % signs
    # SMELL: should collapse these into one. The duplication is pretty
    # pointless.
    $prefs->setInternalPreferences(
        BASEWEB        => $this->{webName},
        BASETOPIC      => $this->{topicName},
        INCLUDINGTOPIC => $this->{topicName},
        INCLUDINGWEB   => $this->{webName}
    );

    # Push plugin settings
    $this->{plugins}->settings();

    # Now the rest of the preferences
    $prefs->loadSitePreferences();

    # User preferences only available if we can get to a valid wikiname,
    # which depends on the user mapper.
    my $wn = $this->{users}->getWikiName( $this->{user} );
    if ($wn) {
        $prefs->setUserPreferences($wn);
    }

    $prefs->pushTopicContext( $this->{webName}, $this->{topicName} );

    #Monitor::MARK("Preferences all set up");

    # Finish plugin initialization - register handlers
    $this->{plugins}->enable();

    Monitor::MARK("Foswiki object created");

    return $this;
}

=begin TML

---++ ObjectMethod renderer()
Get a reference to the renderer object. Done lazily because not everyone
needs the renderer.

=cut

sub renderer {
    my ($this) = @_;

    unless ( $this->{renderer} ) {
        require Foswiki::Render;
        $this->{renderer} = new Foswiki::Render($this);
    }
    return $this->{renderer};
}

=begin TML

---++ ObjectMethod attach()
Get a reference to the attach object. Done lazily because not everyone
needs the attach.

=cut

sub attach {
    my ($this) = @_;

    unless ( $this->{attach} ) {
        require Foswiki::Attach;
        $this->{attach} = new Foswiki::Attach($this);
    }
    return $this->{attach};
}

=begin TML

---++ ObjectMethod templates()
Get a reference to the templates object. Done lazily because not everyone
needs the templates.

=cut

sub templates {
    my ($this) = @_;

    unless ( $this->{templates} ) {
        require Foswiki::Templates;
        $this->{templates} = new Foswiki::Templates($this);
    }
    return $this->{templates};
}

=begin TML

---++ ObjectMethod i18n()
Get a reference to the i18n object. Done lazily because not everyone
needs the i18ner.

=cut

sub i18n {
    my ($this) = @_;

    unless ( $this->{i18n} ) {
        require Foswiki::I18N;

        # language information; must be loaded after
        # *all possible preferences sources* are available
        $this->{i18n} = new Foswiki::I18N($this);
    }
    return $this->{i18n};
}

=begin TML

---++ ObjectMethod logger()

=cut

sub logger {
    my $this = shift;

    unless ( $this->{logger} ) {
        if ( $Foswiki::cfg{Log}{Implementation} eq 'none' ) {
            $this->{logger} = Foswiki::Logger->new();
        }
        else {
            eval "require $Foswiki::cfg{Log}{Implementation}";
            if ($@) {
                print STDERR "Logger load failed: $@";
                $this->{logger} = Foswiki::Logger->new();
            }
            else {
                $this->{logger} = $Foswiki::cfg{Log}{Implementation}->new();
            }
        }
    }

    return $this->{logger};
}

=begin TML

---++ ObjectMethod search()
Get a reference to the search object. Done lazily because not everyone
needs the searcher.

=cut

sub search {
    my ($this) = @_;

    unless ( $this->{search} ) {
        require Foswiki::Search;
        $this->{search} = new Foswiki::Search($this);
    }
    return $this->{search};
}

=begin TML

---++ ObjectMethod net()
Get a reference to the net object. Done lazily because not everyone
needs the net.

=cut

sub net {
    my ($this) = @_;

    unless ( $this->{net} ) {
        require Foswiki::Net;
        $this->{net} = new Foswiki::Net($this);
    }
    return $this->{net};
}

=begin TML

---++ ObjectMethod access()
Get a reference to the ACL object. 

=cut

sub access {
    my ($this) = @_;

    unless ( $this->{access} ) {
        require Foswiki::Access;
        $this->{access} = Foswiki::Access->new($this);
    }
    ASSERT( $this->{access} ) if DEBUG;
    return $this->{access};
}

=begin TML

---++ ObjectMethod DESTROY()

called by Perl when the Foswiki object goes out of scope
(maybe should be used kist to ASSERT that finish() was called..

=cut

#sub DESTROY {
#    my $this = shift;
#    $this->finish();
#}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;

    # Print any macros that are never loaded
    #print STDERR "NEVER USED\n";
    #for my $i (keys %macros) {
    #    print STDERR "\t$i\n" unless defined $macros{$i};
    #}
    $_->finish() foreach values %{ $this->{forms} };
    undef $this->{forms};
    foreach my $key (
        qw(plugins users prefs templates renderer net
        store search attach access i18n cache logger)
      )
    {
        next
          unless ref( $this->{$key} );
        $this->{$key}->finish();
        undef $this->{$key};
    }

    undef $this->{_zones};
    undef $this->{_renderZonePlaceholder};

    undef $this->{request};
    undef $this->{cgiQuery};

    undef $this->{digester};
    undef $this->{urlHost};
    undef $this->{web};
    undef $this->{topic};
    undef $this->{webName};
    undef $this->{topicName};
    undef $this->{_ICONSPACE};
    undef $this->{_EXT2ICON};
    undef $this->{_KNOWNICON};
    undef $this->{_ICONSTEMPLATE};
    undef $this->{context};
    undef $this->{remoteUser};
    undef $this->{requestedWebName};    # Web name before renaming
    undef $this->{scriptUrlPath};
    undef $this->{user};
    undef $this->{_INCLUDES};
    undef $this->{response};
    undef $this->{evaluating_if};
    undef $this->{_addedToHEAD};
    undef $this->{sandbox};
    undef $this->{evaluatingEval};

    undef $this->{DebugVerificationCode};    # from Foswiki::UI::Register
    if (SINGLE_SINGLETONS_TRACE) {
        require Data::Dumper;
        print STDERR "finish $this: "
          . Data::Dumper->Dump( [ [caller], [ caller(1) ] ] );
    }
    if (SINGLE_SINGLETONS) {
        ASSERT( defined $Foswiki::Plugins::SESSION );
        ASSERT( $Foswiki::Plugins::SESSION == $this );
        ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') );
    }
    undef $Foswiki::Plugins::SESSION;

    if (DEBUG) {
        my $remaining = join ',', grep { defined $this->{$_} } keys %$this;
        ASSERT( 0,
                "Fields with defined values in "
              . ref($this)
              . "->finish(): "
              . $remaining )
          if $remaining;
    }
}

=begin TML

---++ ObjectMethod logEvent( $action, $webTopic, $extra, $user )
   * =$action= - what happened, e.g. view, save, rename
   * =$webTopic= - what it happened to
   * =$extra= - extra info, such as minor flag
   * =$user= - login name of user - default current user,
     or failing that the user agent

Write the log for an event to the logfile

=cut

sub logEvent {
    my $this = shift;

    my $action   = shift || '';
    my $webTopic = shift || '';
    my $extra    = shift || '';
    my $user     = shift;

    return
      if ( defined $Foswiki::cfg{Log}{Action}{$action}
        && !$Foswiki::cfg{Log}{Action}{$action} );

    $user ||= $this->{user};
    $user = ( $this->{users}->getLoginName($user) || 'unknown' )
      if ( $this->{users} );

    my $cgiQuery = $this->{request};
    if ($cgiQuery) {
        my $agent = $cgiQuery->user_agent();
        if ($agent) {
            $extra .= ' ' if $extra;
            if ( $agent =~
/(MSIE 6|MSIE 7|MSIE 8|MSI 9|Firefox|Opera|Konqueror|Chrome|Safari)/
              )
            {
                $extra .= $1;
            }
            else {
                $agent =~ m/([\w]+)/;
                $extra .= $1;
            }
        }
    }

    my $remoteAddr = $this->{request}->remoteAddress() || '';

    $this->logger->log( 'info', $user, $action, $webTopic, $extra,
        $remoteAddr );
}

=begin TML

---++ StaticMethod validatePattern( $pattern ) -> $pattern

Validate a pattern provided in a parameter to $pattern so that
dangerous chars (interpolation and execution) are disabled.

=cut

sub validatePattern {
    my $pattern = shift;

    # Escape unescaped $ and @ characters that might interpolate
    # an internal variable.
    # There is no need to defuse (??{ and (?{ as perl won't allow
    # it anyway, unless one uses re 'eval' which we won't do
    $pattern =~ s/(^|[^\\])([\$\@])/$1\\$2/g;
    return $pattern;
}

=begin TML

---++ ObjectMethod inlineAlert($template, $def, ... ) -> $string

Format an error for inline inclusion in rendered output. The message string
is obtained from the template 'oops'.$template, and the DEF $def is
selected. The parameters (...) are used to populate %PARAM1%..%PARAMn%

=cut

sub inlineAlert {
    my $this     = shift;
    my $template = shift;
    my $def      = shift;

    # web and topic can be anything; they are not used
    my $topicObject =
      Foswiki::Meta->new( $this, $this->{webName}, $this->{topicName} );
    my $text = $this->templates->readTemplate( 'oops' . $template );
    if ($text) {
        my $blah = $this->templates->expandTemplate($def);
        $text =~ s/%INSTANTIATE%/$blah/;

        $text = $topicObject->expandMacros($text);
        my $n = 1;
        while ( defined( my $param = shift ) ) {
            $text =~ s/%PARAM$n%/$param/g;
            $n++;
        }

        # Suppress missing params
        $text =~ s/%PARAM\d+%//g;

        # Suppress missing params
        $text =~ s/%PARAM\d+%//g;
    }
    else {

        # Error in the template system.
        $text = $topicObject->renderTML(<<MESSAGE);
---+ Foswiki Installation Error
Template 'oops$template' not found or returned no text, expanding $def.

Check your configuration settings for {TemplateDir} and {TemplatePath}
or check for syntax errors in templates,  or a missing TMPL:END.
MESSAGE
    }

    return $text;
}

=begin TML

---++ StaticMethod parseSections($text) -> ($string,$sectionlistref)

Generic parser for sections within a topic. Sections are delimited
by STARTSECTION and ENDSECTION, which may be nested, overlapped or
otherwise abused. The parser builds an array of sections, which is
ordered by the order of the STARTSECTION within the topic. It also
removes all the SECTION tags from the text, and returns the text
and the array of sections.

Each section is a =Foswiki::Attrs= object, which contains the attributes
{type, name, start, end}
where start and end are character offsets in the
string *after all section tags have been removed*. All sections
are required to be uniquely named; if a section is unnamed, it
will be given a generated name. Sections may overlap or nest.

See test/unit/Fn_SECTION.pm for detailed testcases that
round out the spec.

=cut

sub parseSections {

    my $text = shift;

    return ( '', [] ) unless defined $text;

    my %sections;
    my @list = ();

    my $seq    = 0;
    my $ntext  = '';
    my $offset = 0;
    foreach my $bit ( split( /(%(?:START|END)SECTION(?:{.*?})?%)/, $text ) ) {
        if ( $bit =~ /^%STARTSECTION(?:{(.*)})?%$/ ) {
            require Foswiki::Attrs;

            # SMELL: unchecked implicit untaint?
            my $attrs = new Foswiki::Attrs($1);
            $attrs->{type} ||= 'section';
            $attrs->{name} =
                 $attrs->{_DEFAULT}
              || $attrs->{name}
              || '_SECTION' . $seq++;
            delete $attrs->{_DEFAULT};
            my $id = $attrs->{type} . ':' . $attrs->{name};
            if ( $sections{$id} ) {

                # error, this named section already defined, ignore
                next;
            }

            # close open unnamed sections of the same type
            foreach my $s (@list) {
                if (   $s->{end} < 0
                    && $s->{type} eq $attrs->{type}
                    && $s->{name} =~ /^_SECTION\d+$/ )
                {
                    $s->{end} = $offset;
                }
            }
            $attrs->{start} = $offset;
            $attrs->{end}   = -1;        # open section
            $sections{$id}  = $attrs;
            push( @list, $attrs );
        }
        elsif ( $bit =~ /^%ENDSECTION(?:{(.*)})?%$/ ) {
            require Foswiki::Attrs;

            # SMELL: unchecked implicit untaint?
            my $attrs = new Foswiki::Attrs($1);
            $attrs->{type} ||= 'section';
            $attrs->{name} = $attrs->{_DEFAULT} || $attrs->{name} || '';
            delete $attrs->{_DEFAULT};
            unless ( $attrs->{name} ) {

                # find the last open unnamed section of this type
                foreach my $s ( reverse @list ) {
                    if (   $s->{end} == -1
                        && $s->{type} eq $attrs->{type}
                        && $s->{name} =~ /^_SECTION\d+$/ )
                    {
                        $attrs->{name} = $s->{name};
                        last;
                    }
                }

                # ignore it if no matching START found
                next unless $attrs->{name};
            }
            my $id = $attrs->{type} . ':' . $attrs->{name};
            if ( !$sections{$id} || $sections{$id}->{end} >= 0 ) {

                # error, no such open section, ignore
                next;
            }
            $sections{$id}->{end} = $offset;
        }
        else {
            $ntext .= $bit;
            $offset = length($ntext);
        }
    }

    # close open sections
    foreach my $s (@list) {
        $s->{end} = $offset if $s->{end} < 0;
    }

    return ( $ntext, \@list );
}

=begin TML

---++ ObjectMethod expandMacrosOnTopicCreation ( $topicObject )

   * =$topicObject= - the topic

Expand only that subset of Foswiki variables that are
expanded during topic creation, in the body text and
PREFERENCE meta only. The expansion is in-place inside
the topic object.

# SMELL: no plugin handler

=cut

sub expandMacrosOnTopicCreation {
    my ( $this, $topicObject ) = @_;

    # Make sure func works, for registered tag handlers
    if (SINGLE_SINGLETONS) {
        ASSERT( defined $Foswiki::Plugins::SESSION );
        ASSERT( $Foswiki::Plugins::SESSION == $this );
    }
    local $Foswiki::Plugins::SESSION = $this;
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    my $text = $topicObject->text();
    if ($text) {

        # Chop out templateonly sections
        my ( $ntext, $sections ) = parseSections($text);
        if ( scalar(@$sections) ) {

            # Note that if named templateonly sections overlap,
            # the behaviour is undefined.
            foreach my $s ( reverse @$sections ) {
                if ( $s->{type} eq 'templateonly' ) {
                    $ntext =
                        substr( $ntext, 0, $s->{start} )
                      . substr( $ntext, $s->{end}, length($ntext) );
                }
                else {

                    # put back non-templateonly sections
                    my $start = $s->remove('start');
                    my $end   = $s->remove('end');
                    $ntext =
                        substr( $ntext, 0, $start )
                      . '%STARTSECTION{'
                      . $s->stringify() . '}%'
                      . substr( $ntext, $start, $end - $start )
                      . '%ENDSECTION{'
                      . $s->stringify() . '}%'
                      . substr( $ntext, $end, length($ntext) );
                }
            }
            $text = $ntext;
        }

        $text = _processMacros( $this, $text, \&_expandMacroOnTopicCreation,
            $topicObject, 16 );

        # expand all variables for type="expandvariables" sections
        ( $ntext, $sections ) = parseSections($text);
        if ( scalar(@$sections) ) {
            foreach my $s ( reverse @$sections ) {
                if ( $s->{type} eq 'expandvariables' ) {
                    my $etext =
                      substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                    $this->innerExpandMacros( \$etext, $topicObject );
                    $ntext =
                        substr( $ntext, 0, $s->{start} ) 
                      . $etext
                      . substr( $ntext, $s->{end}, length($ntext) );
                }
                else {

                    # put back non-expandvariables sections
                    my $start = $s->remove('start');
                    my $end   = $s->remove('end');
                    $ntext =
                        substr( $ntext, 0, $start )
                      . '%STARTSECTION{'
                      . $s->stringify() . '}%'
                      . substr( $ntext, $start, $end - $start )
                      . '%ENDSECTION{'
                      . $s->stringify() . '}%'
                      . substr( $ntext, $end, length($ntext) );
                }
            }
            $text = $ntext;
        }

        # kill markers used to prevent variable expansion
        $text =~ s/%NOP%//g;
        $topicObject->text($text);
    }

    # Expand preferences
    my @prefs = $topicObject->find('PREFERENCE');
    foreach my $p (@prefs) {
        $p->{value} =
          _processMacros( $this, $p->{value}, \&_expandMacroOnTopicCreation,
            $topicObject, 16 );

        # kill markers used to prevent variable expansion
        $p->{value} =~ s/%NOP%//g;
    }
}

=begin TML

---++ StaticMethod entityEncode( $text, $extras ) -> $encodedText

Escape special characters to HTML numeric entities. This is *not* a generic
encoding, it is tuned specifically for use in Foswiki.

HTML4.0 spec:
"Certain characters in HTML are reserved for use as markup and must be
escaped to appear literally. The "&lt;" character may be represented with
an <em>entity</em>, <strong class=html>&amp;lt;</strong>. Similarly, "&gt;"
is escaped as <strong class=html>&amp;gt;</strong>, and "&amp;" is escaped
as <strong class=html>&amp;amp;</strong>. If an attribute value contains a
double quotation mark and is delimited by double quotation marks, then the
quote should be escaped as <strong class=html>&amp;quot;</strong>.

Other entities exist for special characters that cannot easily be entered
with some keyboards..."

This method encodes HTML special and any non-printable ascii
characters (except for \n and \r) using numeric entities.

FURTHER this method also encodes characters that are special in Foswiki
meta-language.

$extras is an optional param that may be used to include *additional*
characters in the set of encoded characters. It should be a string
containing the additional chars.

=cut

sub entityEncode {
    my ( $text, $extra ) = @_;
    $extra ||= '';

    # encode all non-printable 7-bit chars (< \x1f),
    # except \n (\xa) and \r (\xd)
    # encode HTML special characters '>', '<', '&', ''' and '"'.
    # encode TML special characters '%', '|', '[', ']', '@', '_',
    # '*', and '='
    $text =~
      s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;
    return $text;
}

=begin TML

---++ StaticMethod entityDecode ( $encodedText ) -> $text

Decodes all numeric entities (e.g. &amp;#123;). _Does not_ decode
named entities such as &amp;amp; (use HTML::Entities for that)

=cut

sub entityDecode {
    my $text = shift;

    $text =~ s/&#(\d+);/chr($1)/ge;
    return $text;
}

=begin TML

---++ StaticMethod urlEncodeAttachment ( $text )

For attachments, URL-encode specially to 'freeze' any characters >127 in the
site charset (e.g. ISO-8859-1 or KOI8-R), by doing URL encoding into native
charset ($siteCharset) - used when generating attachment URLs, to enable the
web server to serve attachments, including images, directly.

This encoding is required to handle the cases of:

    - browsers that generate UTF-8 URLs automatically from site charset URLs - now quite common
    - web servers that directly serve attachments, using the site charset for
      filenames, and cannot convert UTF-8 URLs into site charset filenames

The aim is to prevent the browser from converting a site charset URL in the web
page to a UTF-8 URL, which is the default.  Hence we 'freeze' the URL into the
site character set through URL encoding.

In two cases, no URL encoding is needed:  For EBCDIC mainframes, we assume that
site charset URLs will be translated (outbound and inbound) by the web server to/from an
EBCDIC character set. For sites running in UTF-8, there's no need for Foswiki to
do anything since all URLs and attachment filenames are already in UTF-8.

=cut

sub urlEncodeAttachment {
    my ($text) = @_;

    my $usingEBCDIC = ( 'A' eq chr(193) );    # Only true on EBCDIC mainframes

    if ( $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/i or $usingEBCDIC ) {

        # Just let browser do UTF-8 URL encoding
        return $text;
    }

    # Freeze into site charset through URL encoding
    return urlEncode($text);
}

=begin TML

---++ StaticMethod urlEncode( $string ) -> encoded string

Encode by converting characters that are illegal in URLs to
their %NN equivalents. This method is used for encoding
strings that must be embedded _verbatim_ in URLs; it cannot
be applied to URLs themselves, as it escapes reserved
characters such as = and ?.

RFC 1738, Dec. '94:
    <verbatim>
    ...Only alphanumerics [0-9a-zA-Z], the special
    characters $-_.+!*'(), and reserved characters used for their
    reserved purposes may be used unencoded within a URL.
    </verbatim>

Reserved characters are $&+,/:;=?@ - these are _also_ encoded by
this method.

This URL-encoding handles all character encodings including ISO-8859-*,
KOI8-R, EUC-* and UTF-8.

This may not handle EBCDIC properly, as it generates an EBCDIC URL-encoded
URL, but mainframe web servers seem to translate this outbound before it hits browser
- see CGI::Util::escape for another approach.

=cut

sub urlEncode {
    my $text = shift;

    $text =~ s/([^0-9a-zA-Z-_.:~!*'\/])/'%'.sprintf('%02x',ord($1))/ge;

    return $text;
}

=begin TML

---++ StaticMethod urlDecode( $string ) -> decoded string

Reverses the encoding done in urlEncode.

=cut

sub urlDecode {
    my $text = shift;

    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

    return $text;
}

=begin TML

---++ StaticMethod isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

sub isTrue {
    my ( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined($value);

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ($value) ? 1 : 0;
}

=begin TML

---++ StaticMethod spaceOutWikiWord( $word, $sep ) -> $string

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter $sep any string may be used as separator between the word components; if $sep is undefined it defaults to a space.

=cut

sub spaceOutWikiWord {
    my ( $word, $sep ) = @_;

    # Both could have the value 0 so we cannot use simple = || ''
    $word = defined($word) ? $word : '';
    $sep  = defined($sep)  ? $sep  : ' ';
    $word =~ s/([$regex{upperAlpha}])([$regex{numeric}])/$1$sep$2/go;
    $word =~ s/([$regex{numeric}])([$regex{upperAlpha}])/$1$sep$2/go;
    $word =~
s/([$regex{lowerAlpha}])([$regex{upperAlpha}$regex{numeric}]+)/$1$sep$2/go;
    $word =~
s/([$regex{upperAlpha}])([$regex{upperAlpha}])(?=[$regex{lowerAlpha}])/$1$sep$2/go;
    return $word;
}

=begin TML

---++ ObjectMethod innerExpandMacros(\$text, $topicObject)
Expands variables by replacing the variables with their
values. Some example variables: %<nop>TOPIC%, %<nop>SCRIPTURL%,
%<nop>WIKINAME%, etc.
$web and $incs are passed in for recursive include expansion. They can
safely be undef.
The rules for tag expansion are:
   1 Tags are expanded left to right, in the order they are encountered.
   1 Tags are recursively expanded as soon as they are encountered -
     the algorithm is inherently single-pass
   1 A tag is not "encountered" until the matching }% has been seen, by
     which time all tags in parameters will have been expanded
   1 Tag expansions that create new tags recursively are limited to a
     set number of hierarchical levels of expansion

=cut

sub innerExpandMacros {
    my ( $this, $text, $topicObject ) = @_;

    # push current context
    my $memTopic = $this->{prefs}->getPreference('TOPIC');
    my $memWeb   = $this->{prefs}->getPreference('WEB');

    # Historically this couldn't be called on web objects.
    my $webContext   = $topicObject->web   || $this->{webName};
    my $topicContext = $topicObject->topic || $this->{topicName};

    $this->{prefs}->setInternalPreferences(
        TOPIC => $topicContext,
        WEB   => $webContext
    );

    # Escape ' !%VARIABLE%'
    $$text =~ s/(?<=\s)!%($regex{tagNameRegex})/&#37;$1/g;

    # Make sure func works, for registered tag handlers
    if (SINGLE_SINGLETONS) {
        ASSERT( defined $Foswiki::Plugins::SESSION );
        ASSERT( $Foswiki::Plugins::SESSION == $this );
    }
    local $Foswiki::Plugins::SESSION = $this;
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    # NOTE TO DEBUGGERS
    # The depth parameter in the following call controls the maximum number
    # of levels of expansion. If it is set to 1 then only macros in the
    # topic will be expanded; macros that they in turn generate will be
    # left unexpanded. If it is set to 2 then the expansion will stop after
    # the first recursive inclusion, and so on. This is incredible useful
    # when debugging. The default, 16, was selected empirically.
    $$text = _processMacros( $this, $$text, \&_expandMacroOnTopicRendering,
        $topicObject, 16 );

    # restore previous context
    $this->{prefs}->setInternalPreferences(
        TOPIC => $memTopic,
        WEB   => $memWeb
    );
}

=begin TML

---++ StaticMethod takeOutBlocks( \$text, $tag, \%map ) -> $text
   * =$text= - Text to process
   * =$tag= - XML-style tag.
   * =\%map= - Reference to a hash to contain the removed blocks

Return value: $text with blocks removed

Searches through $text and extracts blocks delimited by an XML-style tag,
storing the extracted block, and replacing with a token string which is
not affected by TML rendering.  The text after these substitutions is
returned.

=cut

sub takeOutBlocks {
    my ( $intext, $tag, $map ) = @_;

    return $intext unless ( $intext =~ m/<$tag\b/i );

    my $out   = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split( /(<\/?$tag[^>]*>)/i, $intext ) ) {
        if ( $token =~ /<$tag\b([^>]*)?>/i ) {
            $depth++;
            if ( $depth eq 1 ) {
                $tagParams = $1;
                next;
            }
        }
        elsif ( $token =~ /<\/$tag>/i ) {
            if ( $depth > 0 ) {
                $depth--;
                if ( $depth eq 0 ) {
                    my $placeholder = "$tag$BLOCKID";
                    $BLOCKID++;
                    $map->{$placeholder}{text}   = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= "$OC$placeholder$CC";
                    $scoop = '';
                    next;
                }
            }
        }
        if ( $depth > 0 ) {
            $scoop .= $token;
        }
        else {
            $out .= $token;
        }
    }

    # unmatched tags
    if ( defined($scoop) && ( $scoop ne '' ) ) {
        my $placeholder = "$tag$BLOCKID";
        $BLOCKID++;
        $map->{$placeholder}{text}   = $scoop;
        $map->{$placeholder}{params} = $tagParams;
        $out .= "$OC$placeholder$CC";
    }

    return $out;
}

=begin TML

---++ StaticMethod putBackBlocks( \$text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =\$text= - reference to text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag.
     If undefined, uses $tag.
   * =$callback= - Reference to function to call on each block
     being inserted (optional)

Reverses the actions of takeOutBlocks.

Each replaced block is processed by the callback (if there is one) before
re-insertion.

Parameters to the outermost cut block are replaced into the open tag,
even if that tag is changed. This allows things like =&lt;verbatim class=''>=
to be changed to =&lt;pre class=''>=

If you set $newtag to '', replaces the taken-out block with the contents
of the block, not including the open/close. This is used for &lt;literal>,
for example.

=cut

sub putBackBlocks {
    my ( $text, $map, $tag, $newtag, $callback ) = @_;

    $newtag = $tag if ( !defined($newtag) );

    foreach my $placeholder ( keys %$map ) {
        if ( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || '';
            my $val = $map->{$placeholder}{text};
            $val = &$callback($val) if ( defined($callback) );
            if ( $newtag eq '' ) {
                $$text =~ s($OC$placeholder$CC)($val);
            }
            else {
                $$text =~ s($OC$placeholder$CC)
                           (<$newtag$params>$val</$newtag>);
            }
            delete( $map->{$placeholder} );
        }
    }
}

# Process Foswiki %TAGS{}% by parsing the input tokenised into
# % separated sections. The parser is a simple stack-based parse,
# sufficient to ensure nesting of tags is correct, but no more
# than that.
# $depth limits the number of recursive expansion steps that
# can be performed on expanded tags.
sub _processMacros {
    my ( $this, $text, $tagf, $topicObject, $depth ) = @_;
    my $tell = 0;

    return '' if ( ( !defined($text) )
        || ( $text eq '' ) );

    #no tags to process
    return $text unless ( $text =~ /%/ );

    unless ($depth) {
        my $mess = "Max recursive depth reached: $text";
        $this->logger->log( 'warning', $mess );

        # prevent recursive expansion that just has been detected
        # from happening in the error message
        $text =~ s/%(.*?)%/$1/go;
        return $text;
    }

    my $verbatim = {};
    $text = takeOutBlocks( $text, 'verbatim', $verbatim );

    my $dirtyAreas = {};
    $text = takeOutBlocks( $text, 'dirtyarea', $dirtyAreas )
      if $Foswiki::cfg{Cache}{Enabled};

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = '';    # the top stack entry. Done this way instead of
         # referring to the top of the stack for efficiency. This var
         # should be considered to be $stack[$#stack]

    while ( scalar(@queue) ) {

        #print STDERR "QUEUE:".join("\n      ", map { "'$_'" } @queue)."\n";
        my $token = shift(@queue);

        #print STDERR ' ' x $tell,"PROCESSING $token \n";

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {

            #print STDERR ' ' x $tell,"CONSIDER $stackTop\n";
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

                    #print STDERR ' ' x $tell,"COLLAPSE $top \n";
                    $stackTop = pop(@stack) . $top;
                }
            }

            # /s so you can have newlines in parameters
            if ( $stackTop =~ m/^%(($regex{tagNameRegex})(?:{(.*)})?)$/so ) {

                # SMELL: unchecked implicit untaint?
                my ( $expr, $tag, $args ) = ( $1, $2, $3 );

                #print STDERR ' ' x $tell,"POP $tag\n";
                #Monitor::MARK("Before $tag");
                my $e = &$tagf( $this, $tag, $args, $topicObject );

                #Monitor::MARK("After $tag");

                if ( defined($e) ) {

                    #print STDERR ' ' x $tell--,"EXPANDED $tag -> $e\n";
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

                    #print STDERR ' ' x $tell++,"EXPAND $tag FAILED\n";
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
                                        #$tell++;
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

    putBackBlocks( \$stackTop, $dirtyAreas, 'dirtyarea' )
      if $Foswiki::cfg{Cache}{Enabled};
    putBackBlocks( \$stackTop, $verbatim, 'verbatim' );

    #print STDERR "FINAL $stackTop\n";

    return $stackTop;
}

# Handle expansion of a tag during topic rendering
# $tag is the tag name
# $args is the bit in the {} (if there are any)
# $topicObject should be passed for dynamic tags (not needed for
# session or constant tags
sub _expandMacroOnTopicRendering {
    my ( $this, $tag, $args, $topicObject ) = @_;

    require Foswiki::Attrs;
    my $attrs;

    my $e = $this->{prefs}->getPreference($tag);
    if ( defined $e ) {
        if ( $args && $args =~ /\S/ ) {
            $attrs = new Foswiki::Attrs( $args, 0 );
            $attrs->{DEFAULT} = $attrs->{_DEFAULT};
            $e = $this->_processMacros(
                $e,
                sub {
                    my ( $this, $tag, $args, $topicObject ) = @_;
                    return
                      defined $attrs->{$tag}
                      ? expandStandardEscapes( $attrs->{$tag} )
                      : undef;
                },
                $topicObject,
                1
            );
        }
    }
    elsif ( exists( $macros{$tag} ) ) {
        unless ( defined( $macros{$tag} ) ) {

            # Demand-load the macro module
            die $tag unless $tag =~ /([A-Z_:]+)/i;
            $tag = $1;
            eval "require Foswiki::Macros::$tag";
            die $@ if $@;
            $macros{$tag} = eval "\\&$tag";
            die $@ if $@;
        }

        $attrs = new Foswiki::Attrs( $args, $contextFreeSyntax{$tag} );
        $e = &{ $macros{$tag} }( $this, $attrs, $topicObject );
    }
    elsif ( $args && $args =~ /\S/ ) {
        $attrs = new Foswiki::Attrs($args);
        if ( defined $attrs->{default} ) {
            $e = expandStandardEscapes( $attrs->{default} );
        }
    }
    return $e;
}

# Handle expansion of a tag during new topic creation. When creating a
# new topic from a template we only expand a subset of the available legal
# tags, and we expand %NOP% differently.
sub _expandMacroOnTopicCreation {
    my $this = shift;

    # my( $tag, $args, $topicObject ) = @_;

    # Required for Cairo compatibility. Ignore %NOP{...}%
    # %NOP% is *not* ignored until all variable expansion is complete,
    # otherwise them inside-out rule would remove it too early e.g.
    # %GM%NOP%TIME -> %GMTIME -> 12:00. So we ignore it here and scrape it
    # out later. We *have* to remove %NOP{...}% because it can foul up
    # brace-matching.
    return '' if $_[0] eq 'NOP' && defined $_[1];

    # Only expand a subset of legal tags. Warning: $this->{user} may be
    # overridden during this call, when a new user topic is being created.
    # This is what we want to make sure new user templates are populated
    # correctly, but you need to think about this if you extend the set of
    # tags expanded here.
    return
      unless $_[0] =~
/^(URLPARAM|DATE|(SERVER|GM)TIME|(USER|WIKI)NAME|WIKIUSERNAME|USERINFO)$/;

    return $this->_expandMacroOnTopicRendering(@_);
}

=begin TML

---++ ObjectMethod enterContext( $id, $val )

Add the context id $id into the set of active contexts. The $val
can be anything you like, but should always evaluate to boolean
TRUE.

An example of the use of contexts is in the use of tag
expansion. The commonTagsHandler in plugins is called every
time tags need to be expanded, and the context of that expansion
is signalled by the expanding module using a context id. So the
forms module adds the context id "form" before invoking common
tags expansion.

Contexts are not just useful for tag expansion; they are also
relevant when rendering.

Contexts are intended for use mainly by plugins. Core modules can
use $session->inContext( $id ) to determine if a context is active.

=cut

sub enterContext {
    my ( $this, $id, $val ) = @_;
    $val ||= 1;
    $this->{context}->{$id} = $val;
}

=begin TML

---++ ObjectMethod leaveContext( $id )

Remove the context id $id from the set of active contexts.
(see =enterContext= for more information on contexts)

=cut

sub leaveContext {
    my ( $this, $id ) = @_;
    my $res = $this->{context}->{$id};
    delete $this->{context}->{$id};
    return $res;
}

=begin TML

---++ ObjectMethod inContext( $id )

Return the value for the given context id
(see =enterContext= for more information on contexts)

=cut

sub inContext {
    my ( $this, $id ) = @_;
    return $this->{context}->{$id};
}

=begin TML

---++ StaticMethod registerTagHandler( $tag, $fnref, $syntax )

STATIC Add a tag handler to the function tag handlers.
   * =$tag= name of the tag e.g. MYTAG
   * =$fnref= Function to execute. Will be passed ($session, \%params, $web, $topic )
   * =$syntax= somewhat legacy - 'classic' or 'context-free' (context-free may be removed in future)


$syntax parameter:
Way back in prehistory, back when the dinosaur still roamed the earth, 
Crawford tried to extend the tag syntax of macros such that they could be processed 
by a context-free parser (hence the "context-free") 
and bring them into line with HTML. 
This work was banjaxed by one particular tyrranosaur, 
who felt that the existing syntax was perfect. 
However by that time Crawford had used it in a couple of places - most notable in the action tracker. 

The syntax isn't vastly different from what's there; the differences are: 
   1 Use either type of quote for parameters 
   2 Optional quotes on parameter values e.g. recurse=on 
   3 Standardised use of \ for escapes 
   4 Boolean (valueless) options (i.e. recurse instead of recurse="on" 


=cut

sub registerTagHandler {
    my ( $tag, $fnref, $syntax ) = @_;
    $macros{$tag} = $fnref;
    if ( $syntax && $syntax eq 'context-free' ) {
        $contextFreeSyntax{$tag} = 1;
    }
}

=begin TML

---++ ObjectMethod expandMacros( $text, $topicObject ) -> $text

Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
'commonTagsHandler' plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

$topicObject may be undef when, for example, expanding templates, or one-off strings
at a time when meta isn't available.

DO NOT CALL THIS DIRECTLY; use $topicObject->expandMacros instead.

=cut

sub expandMacros {
    my ( $this, $text, $topicObject ) = @_;

    return '' unless defined $text;

    # Plugin Hook (for cache Plugins only)
    $this->{plugins}
      ->dispatch( 'beforeCommonTagsHandler', $text, $topicObject->topic,
        $topicObject->web, $topicObject );

    #use a "global var", so included topics can extract and putback
    #their verbatim blocks safetly.
    my $verbatim = {};
    $text = takeOutBlocks( $text, 'verbatim', $verbatim );

    # take out dirty areas
    my $dirtyAreas = {};
    $text = takeOutBlocks( $text, 'dirtyarea', $dirtyAreas )
      if $Foswiki::cfg{Cache}{Enabled};

    # Require defaults for plugin handlers :-(
    my $webContext   = $topicObject->web   || $this->{webName};
    my $topicContext = $topicObject->topic || $this->{topicName};

    my $memW = $this->{prefs}->getPreference('INCLUDINGWEB');
    my $memT = $this->{prefs}->getPreference('INCLUDINGTOPIC');
    $this->{prefs}->setInternalPreferences(
        INCLUDINGWEB   => $webContext,
        INCLUDINGTOPIC => $topicContext
    );

    $this->innerExpandMacros( \$text, $topicObject );

    $text = takeOutBlocks( $text, 'verbatim', $verbatim );

    # Plugin Hook
    $this->{plugins}
      ->dispatch( 'commonTagsHandler', $text, $topicContext, $webContext, 0,
        $topicObject );

    # process tags again because plugin hook may have added more in
    $this->innerExpandMacros( \$text, $topicObject );

    $this->{prefs}->setInternalPreferences(
        INCLUDINGWEB   => $memW,
        INCLUDINGTOPIC => $memT
    );

    # 'Special plugin tag' TOC hack, must be done after all other expansions
    # are complete, and has to reprocess the entire topic.

    if ( $text =~ /%TOC(?:{.*})?%/ ) {
        require Foswiki::Macros::TOC;
        $text =~ s/%TOC(?:{(.*?)})?%/$this->TOC($text, $topicObject, $1)/ge;
    }

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering in order to join
    # table rows properly
    $text =~ s/^<nop>\r?\n//gm;

    # restore dirty areas
    putBackBlocks( \$text, $dirtyAreas, 'dirtyarea' )
      if $Foswiki::cfg{Cache}{Enabled};

    putBackBlocks( \$text, $verbatim, 'verbatim' );

    # Foswiki Plugin Hook (for cache Plugins only)
    $this->{plugins}
      ->dispatch( 'afterCommonTagsHandler', $text, $topicContext, $webContext,
        $topicObject );

    return $text;
}

=begin TML

---++ ObjectMethod addToZone($zone, $id, $data, $requires)

Add =$data= identified as =$id= to =$zone=, which will later be expanded (with
renderZone() - implements =%<nop>RENDERZONE%=). =$ids= are unique within
the zone that they are added - dependencies between =$ids= in different zones 
will not be resolved, except for the special case of =head= and =script= zones
when ={MergeHeadAndScriptZones}= is enabled.

In this case, they are treated as separate zones when adding to them, but as
one merged zone when rendering, i.e. a call to render either =head= or =script=
zones will actually render both zones in this one call. Both zones are undef'd
afterward to avoid double rendering of content from either zone, to support
proper behaviour when =head= and =script= are rendered with separate calls even
when ={MergeHeadAndScriptZones}= is set. See ZoneTests/explicit_RENDERZONE*.

This behaviour allows an addToZone('head') call to require an id that has been
added to =script= only.

   * =$zone=      - name of the zone
   * =$id=        - unique identifier
   * =$data=      - content
   * =$requires=  - optional, comma-separated string of =$id= identifiers
                    that should precede the content

<blockquote class="foswikiHelp">%X%
*Note:* Read the developer supplement at Foswiki:Development.AddToZoneFromPluginHandlers if you
are calling =addToZone()= from a rendering or macro/tag-related plugin handler
</blockquote>

Implements =%<nop>ADDTOZONE%=.

=cut

sub addToZone {
    my ( $this, $zone, $id, $data, $requires ) = @_;

    $requires ||= '';

    # get a random one
    unless ($id) {
        $id = int( rand(10000) ) + 1;
    }

    # get zone, or create record
    my $thisZone = $this->{_zones}{$zone};
    unless ( defined $thisZone ) {
        $this->{_zones}{$zone} = $thisZone = {};
    }

    my @requires;
    foreach my $req ( split( /\s*,\s*/, $requires ) ) {
        unless ( $thisZone->{$req} ) {
            $thisZone->{$req} = {
                id              => $req,
                zone            => $zone,
                requires        => [],
                missingrequires => [],
                text            => '',
                populated       => 0
            };
        }
        push( @requires, $thisZone->{$req} );
    }

    # store record within zone
    my $zoneID = $thisZone->{$id};
    unless ($zoneID) {
        $zoneID = { id => $id };
        $thisZone->{$id} = $zoneID;
    }

    # override previous properties
    $zoneID->{zone}            = $zone;
    $zoneID->{requires}        = \@requires;
    $zoneID->{missingrequires} = [];
    $zoneID->{text}            = $data;
    $zoneID->{populated}       = 1;

    return;
}

sub _renderZoneById {
    my $this = shift;
    my $id   = shift;

    return '' unless defined $id;

    my $renderZone = $this->{_renderZonePlaceholder}{$id};

    return '' unless defined $renderZone;

    my $params      = $renderZone->{params};
    my $topicObject = $renderZone->{topicObject};
    my $zone        = $params->{_DEFAULT} || $params->{zone};

    return _renderZone( $this, $zone, $params, $topicObject );
}

# This private function is used in ZoneTests
sub _renderZone {
    my ( $this, $zone, $params, $topicObject ) = @_;

    # Check the zone is defined and has not already been rendered
    return '' unless $zone && $this->{_zones}{$zone};

    $params->{header} ||= '';
    $params->{footer} ||= '';
    $params->{chomp}  ||= 'off';
    $params->{missingformat} = '$id: requires= missing ids: $missingids';
    $params->{format}        = '$item<!--<literal>$missing</literal>-->'
      unless defined $params->{format};
    $params->{separator} = '$n()' unless defined $params->{separator};

    unless ( defined $topicObject ) {
        $topicObject =
          Foswiki::Meta->new( $this, $this->{webName}, $this->{topicName} );
    }

    # Loop through the vertices of the graph, in any order, initiating
    # a depth-first search for any vertex that has not already been
    # visited by a previous search. The desired topological sorting is
    # the reverse postorder of these searches. That is, we can construct
    # the ordering as a list of vertices, by adding each vertex to the
    # start of the list at the time when the depth-first search is
    # processing that vertex and has returned from processing all children
    # of that vertex. Since each edge and vertex is visited once, the
    # algorithm runs in linear time.
    my %visited;
    my @total;

    # When {MergeHeadAndScriptZones} is set, try to treat head and script
    # zones as merged for compatibility with ADDTOHEAD usage where requirements
    # have been moved to the script zone. See ZoneTests/Item9317
    if ( $Foswiki::cfg{MergeHeadAndScriptZones}
        and ( ( $zone eq 'head' ) or ( $zone eq 'script' ) ) )
    {
        my @zoneIDs = (
            values %{ $this->{_zones}{head} },
            values %{ $this->{_zones}{script} }
        );

        foreach my $zoneID (@zoneIDs) {
            $this->_visitZoneID( $zoneID, \%visited, \@total );
        }
        undef $this->{_zones}{head};
        undef $this->{_zones}{script};
    }
    else {
        my @zoneIDs = values %{ $this->{_zones}{$zone} };

        foreach my $zoneID (@zoneIDs) {
            $this->_visitZoneID( $zoneID, \%visited, \@total );
        }

        # kill a zone once it has been rendered, to prevent it being
        # added twice (e.g. by duplicate %RENDERZONEs or by automatic
        # zone expansion in the head or script)
        undef $this->{_zones}{$zone};
    }

    # nothing rendered for a zone with no ADDTOZONE calls
    return '' unless scalar(@total) > 0;

    my @result        = ();
    my $missingformat = $params->{missingformat};
    foreach my $item (@total) {
        my $text       = $item->{text};
        my @missingids = @{ $item->{missingrequires} };
        my $missingformat =
          ( scalar(@missingids) ) ? $params->{missingformat} : '';

        if ( $params->{'chomp'} ) {
            $text =~ s/^\s+//g;
            $text =~ s/\s+$//g;
        }

        # ASSERT($text, "No content for zone id $item->{id} in zone $zone")
        # if DEBUG;

        next unless $text;
        my $id = $item->{id} || '';
        my $line = $params->{format};
        if ( scalar(@missingids) ) {
            $line =~ s/\$missing\b/$missingformat/g;
            $line =~ s/\$missingids\b/join(', ', @missingids)/ge;
        }
        else {
            $line =~ s/\$missing\b/\$id/g;
        }
        $line =~ s/\$item\b/$text/g;
        $line =~ s/\$id\b/$id/g;
        $line =~ s/\$zone\b/$item->{zone}/g;
        push @result, $line if $line;
    }
    my $result =
      expandStandardEscapes( $params->{header}
          . join( $params->{separator}, @result )
          . $params->{footer} );

    # delay rendering the zone until now
    $result = $topicObject->expandMacros($result);
    $result = $topicObject->renderTML($result);

    return $result;
}

sub _visitZoneID {
    my ( $this, $zoneID, $visited, $list ) = @_;

    return if $visited->{$zoneID};

    $visited->{$zoneID} = 1;

    foreach my $requiredZoneID ( @{ $zoneID->{requires} } ) {
        my $zoneIDToVisit;

        if ( $Foswiki::cfg{MergeHeadAndScriptZones}
            and not $requiredZoneID->{populated} )
        {

            # Compatibility mode, where we are trying to treat head and script
            # zones as merged, and a required ZoneID isn't populated. Try
            # opposite zone to see if it exists there instead. Item9317
            if ( $requiredZoneID->{zone} eq 'head' ) {
                $zoneIDToVisit =
                  $this->{_zones}{script}{ $requiredZoneID->{id} };
            }
            else {
                $zoneIDToVisit = $this->{_zones}{head}{ $requiredZoneID->{id} };
            }
            if ( not $zoneIDToVisit->{populated} ) {

                # Oops, the required ZoneID doesn't exist there either; reset
                $zoneIDToVisit = $requiredZoneID;
            }
        }
        else {
            $zoneIDToVisit = $requiredZoneID;
        }
        $this->_visitZoneID( $zoneIDToVisit, $visited, $list );

        if ( not $zoneIDToVisit->{populated} ) {

            # Finally, we got to here and the required ZoneID just cannot be
            # found in either head or script (or other) zones, so record it for
            # diagnostic purposes ($missingids format token)
            push( @{ $zoneID->{missingrequires} }, $zoneIDToVisit->{id} );
        }
    }
    push( @{$list}, $zoneID );

    return;
}

# This private function is used in ZoneTests
sub _renderZones {
    my ( $this, $text ) = @_;

    # Render zones that were pulled out by Foswiki/Macros/RENDERZONE.pm
    # NOTE: once a zone has been rendered it is cleared, so cannot
    # be rendered again.

    $text =~ s/${RENDERZONE_MARKER}RENDERZONE{(.*?)}${RENDERZONE_MARKER}/
      _renderZoneById($this, $1)/geo;

    # get the head zone and insert it at the end of the </head>
    # *if it has not already been rendered*
    my $headZone = _renderZone( $this, 'head', { chomp => "on" } );
    $text =~ s!(</head>)!$headZone\n$1!i if $headZone;

  # SMELL: Item9480 - can't trust that _renderzone(head) above has truly
  # flushed both script and head zones empty when {MergeHeadAndScriptZones} = 1.
    my $scriptZone = _renderZone( $this, 'script', { chomp => "on" } );
    $text =~ s!(</head>)!$scriptZone\n$1!i if $scriptZone;

    chomp($text);

    return $text;
}

=begin TML

---++ StaticMethod readFile( $filename ) -> $text

Returns the entire contents of the given file, which can be specified in any
format acceptable to the Perl open() function. Fast, but inherently unsafe.

WARNING: Never, ever use this for accessing topics or attachments! Use the
Store API for that. This is for global control files only, and should be
used *only* if there is *absolutely no alternative*.

=cut

sub readFile {
    my $name = shift;
    my $IN_FILE;
    open( $IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <$IN_FILE>;
    close($IN_FILE);
    $data = '' unless ( defined($data) );
    return $data;
}

=begin TML

---++ StaticMethod expandStandardEscapes($str) -> $unescapedStr

Expands standard escapes used in parameter values to block evaluation. See
System.FormatTokens for a full list of supported tokens.

=cut

sub expandStandardEscapes {
    my $text = shift;

    # expand '$n()' and $n! to new line
    $text =~ s/\$n\(\)/\n/gs;
    $text =~ s/\$n(?=[^$regex{mixedAlpha}]|$)/\n/gos;

    # filler, useful for nested search
    $text =~ s/\$nop(\(\))?//gs;

    # $quot -> "
    $text =~ s/\$quot(\(\))?/\"/gs;

    # $comma -> ,
    $text =~ s/\$comma(\(\))?/,/gs;

    # $percent -> %
    $text =~ s/\$perce?nt(\(\))?/\%/gs;

    # $lt -> <
    $text =~ s/\$lt(\(\))?/\</gs;

    # $gt -> >
    $text =~ s/\$gt(\(\))?/\>/gs;

    # $amp -> &
    $text =~ s/\$amp(\(\))?/\&/gs;

    # $dollar -> $, done last to avoid creating the above tokens
    $text =~ s/\$dollar(\(\))?/\$/gs;

    return $text;
}

=begin TML

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

A web _has_ to have a preferences topic to be a web.

=cut

sub webExists {
    my ( $this, $web ) = @_;

    ASSERT( UNTAINTED($web), 'web is tainted' ) if DEBUG;
    return $this->{store}->webExists($web);
}

=begin TML

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

=cut

sub topicExists {
    my ( $this, $web, $topic ) = @_;
    ASSERT( UNTAINTED($web),   'web is tainted' )   if DEBUG;
    ASSERT( UNTAINTED($topic), 'topic is tainted' ) if DEBUG;
    return $this->{store}->topicExists( $web, $topic );
}

=begin TML

---+++ ObjectMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins etc. The directory will exist.

=cut

sub getWorkArea {
    my ( $this, $key ) = @_;
    return $this->{store}->getWorkArea($key);
}

=begin TML

---++ ObjectMethod getApproxRevTime (  $web, $topic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

SMELL: is there a reason this is in Foswiki.pm, and not in Search?

=cut

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $metacache = $this->search->metacache;
    if ( $metacache->hasCached( $web, $topic ) ) {

        #don't kill me - this should become a property on Meta
        return $metacache->get( $web, $topic )->{modified};
    }

    return $this->{store}->getApproxRevTime( $web, $topic );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
