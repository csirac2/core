# See bottom of file for license and copyright information
package Foswiki::Logger::Compatibility;

use strict;
use warnings;
use utf8;
use Assert;

use Foswiki::Logger ();
our @ISA = ('Foswiki::Logger');

=begin TML

---+ package Foswiki::Logger::Compatibility

Compatibility with old LocalSite.cfg settings, if user has not run
configure yet. This logger is automatically used if Foswiki senses
that the LocalSite.cfg hasn't been modified for 1.1 (configure has
not been run yet). It may also be explicitly selected in
=configure=.

Plain file implementation of the Foswiki Logger interface. Mostly
compatible with TWiki (and Foswiki 1.0.0) log files, except that dates
are recorded using ISO format, and include the time, and it dies when
a log can't be written (rather than printing a warning).

This logger implementation maps groups of levels to a single logfile, viz.
   * =debug= messages are output to $Foswiki::cfg{DebugFileName}
   * =info= messages are output to $Foswiki::cfg{LogFileName}
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output to $Foswiki::cfg{WarningFileName}.
   * =error=, =critical=, =alert=, and =emergency= messages are also
     written to standard error (the webserver log file, usually)

This is a copy of the Foswiki 1.0 code.

=cut

use Foswiki::Time              ();
use Foswiki::ListIterator      ();
use Foswiki::AggregateIterator ();
use Foswiki::Configure::Load   ();
use Fcntl qw(:flock);

# Local symbol used so we can override it during unit testing
sub _time { return time() }

sub new {
    my $class = shift;
    return bless( { acceptsHash => 1, }, $class );
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my $this = shift;
    my $level;
    my @fields;

    # Native interface:  Convert the hash back to list format
    if ( ref( $_[0] ) eq 'HASH' ) {
        ( $level, @fields ) = Foswiki::Logger::getOldCall(@_);
        return unless defined $level;
    }
    else {
        ( $level, @fields ) = @_;
    }

    my $log = _getLogForLevel( [$level] );

    my $now = _time();
    $log = _expandDATE( $log, $now );
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );

    # Unfortunate compatibility requirement; need the level, but the old
    # logfile format doesn't allow us to add fields. Since we are changing
    # the date format anyway, the least pain is to concatenate the level
    # to the date; Foswiki::Time::ParseTime can handle it, and it looks
    # OK too.
    unshift( @fields, "$time $level" );
    my $message =
      '| ' . join( ' | ', map { s/\|/&vbar;/g; $_ } @fields ) . ' |';

    my $file;
    my $mode = '>>';

    # Item10764, SMELL UNICODE: actually, perhaps we should open the stream this
    # way for any encoding, not just utf8. Babar says: check what Catalyst does.
    if (   $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/ )
    {
        $mode .= ":encoding($Foswiki::cfg{Site}{CharSet})";
    }
    elsif ( utf8::is_utf8($message) ) {
        require Encode;
        $message = Encode::encode( $Foswiki::cfg{Site}{CharSet}, $message, 0 );
    }

    if ( open( $file, $mode, $log ) ) {
        print $file "$message\n";
        close($file);
    }
    else {
        die 'ERROR: Could not write ' . $message . ' to ' . "$log: $!\n";
    }
    if ( $level =~ /^(error|critical|alert|emergency)$/ ) {
        print STDERR "$message\n";
    }
}

{

    # Private subclass of LineIterator that splits events into fields
    package Foswiki::Logger::Compatibility::EventIterator;
    use Fcntl qw(:flock);
    require Foswiki::LineIterator;
    our @ISA = ('Foswiki::LineIterator');

    sub new {
        my ( $class, $fh, $threshold, $level, $numLevels, $version ) = @_;
        my $this = $class->SUPER::new($fh);
        $this->{_multilevel} = ( $numLevels > 1 );
        $this->{_api}        = $version;
        $this->{_threshold}  = $threshold;
        $this->{_reqLevel}   = $level;
        return $this;
    }

    sub DESTROY {
        my $this = shift;
        flock( $this->{handle}, LOCK_UN )
          if ( defined $this->{logLocked} );
        close( delete $this->{handle} ) if ( defined $this->{handle} );
    }

    sub hasNext {
        my $this = shift;
        return 1 if defined $this->{_nextEvent};
        while ( $this->SUPER::hasNext() ) {
            my $ln = $this->SUPER::next();
            while ( substr( $ln, -1 ) ne '|' && $this->SUPER::hasNext() ) {
                $ln .= "\n" . $this->SUPER::next();
            }
            my @line = split( /\s*\|\s*/, $ln );
            shift @line;    # skip the leading empty cell
            next unless scalar(@line) && defined $line[0];
            if (
                $line[0] =~ s/\s+($this->{_reqLevel})\s*$//    # test the level
                  # accept a plain 'old' format date with no level only if reading info (statistics)
                || $line[0] =~ /^\d{1,2} [a-z]{3} \d{4}/i
                && $this->{_reqLevel} =~ m/info/
              )
            {
                $this->{_level} = $1 || 'info';
                $line[0] = Foswiki::Time::parseTime( $line[0] );
                next
                  unless ( defined $line[0] )
                  ;    # Skip record if time doesn't decode.
                if ( $line[0] >= $this->{_threshold} ) {    # test the time
                    $this->{_nextEvent} = \@line;
                    return 1;
                }
            }
        }
        return 0;
    }

    #
    #   1 date of the event (seconds since the epoch)
    #   1 login name of the user who triggered the event
    #   1 the event name (the $action passed to =writeEvent=)
    #   1 the Web.Topic that the event applied to
    #   1 Extras (the $extra passed to =writeEvent=)
    #   1 The IP address that was the source of the event (if known)
    #
    sub next {
        my $this = shift;
        my ( $fhash, $data ) =
          $this->parseRecord( $this->{_level}, $this->{_nextEvent} );
        undef $this->{_nextEvent};
        return $data;
    }

    sub parseRecord {
        my $this  = shift;
        my $level = shift;    # Level parsed from record or assumed.
        my $data  = shift;    # Array ref of raw fields from record.
        my %fhash;            # returned hash of identified fields
        $fhash{level} = $level;
        if ( $level eq 'info' ) {
            $fhash{epoch}      = shift @$data;
            $fhash{user}       = shift @$data;
            $fhash{action}     = shift @$data;
            $fhash{webTopic}   = shift @$data;
            $fhash{extra}      = shift @$data;
            $fhash{remoteAddr} = shift @$data;
        }
        elsif ( $level =~ m/warning|error|critical|alert|emergency/ ) {
            $fhash{epoch} = shift @$data;
            $fhash{extra} = join( ' ', @$data );
        }
        elsif ( $level eq 'debug' ) {
            $fhash{epoch} = shift @$data;
            $fhash{extra} = join( ' ', @$data );
        }
        return \%fhash,

          (
            [
                $fhash{epoch},
                $fhash{user}       || '',
                $fhash{action}     || '',
                $fhash{webTopic}   || '',
                $fhash{extra}      || '',
                $fhash{remoteAddr} || '',
                $fhash{level},
            ]
          );
    }
}

=begin TML

---++ StaticMethod eachEventSince($time, $level) -> $iterator

See Foswiki::Logger for the interface.

This logger implementation maps groups of levels to a single logfile, viz.
   * =info= messages are output together.
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output together.
This method cannot 

=cut

sub eachEventSince {
    my ( $this, $time, $level, $version ) = @_;

    $level = ref $level ? $level : [$level];    # Convert level to array.
    my $numLevels = scalar @$level;

    #SMELL: Only returns a single logfile for now
    my $log = _getLogForLevel($level);

    # Find the year-month for the current time
    my $now          = _time();
    my $lastLogYear  = Foswiki::Time::formatTime( $now, '$year', 'servertime' );
    my $lastLogMonth = Foswiki::Time::formatTime( $now, '$mo', 'servertime' );

    # Find the year-month for the first time in the range
    my $logYear  = $lastLogYear;
    my $logMonth = $lastLogMonth;
    if ( $log =~ /%DATE%/ ) {
        $logYear  = Foswiki::Time::formatTime( $time, '$year', 'servertime' );
        $logMonth = Foswiki::Time::formatTime( $time, '$mo',   'servertime' );
    }

    # Convert requested level to a regex
    my $reqLevel = join( '|', @$level );
    $reqLevel = qr/(?:$reqLevel)/;

    # Enumerate over all the logfiles in the time range, creating an
    # iterator for each.
    my @iterators;
    while (1) {
        my $logfile = $log;
        my $logTime = $logYear . sprintf( "%02d", $logMonth );
        $logfile =~ s/%DATE%/$logTime/g;
        my $fh;
        if ( open( $fh, '<', $logfile ) ) {
            my $logIt =
              new Foswiki::Logger::Compatibility::EventIterator( $fh, $time,
                $reqLevel, $numLevels, $version );
            $logIt->{logLocked} =
              eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
            push( @iterators, $logIt );
        }
        else {

            # Would be nice to report this, but it's chicken and egg and
            # besides, empty logfiles can happen.
            #print STDERR "Failed to open $logfile: $!";
        }
        last if $logMonth == $lastLogMonth && $logYear == $lastLogYear;
        $logMonth++;
        if ( $logMonth == 13 ) {
            $logMonth = 1;
            $logYear++;
        }
    }
    return new Foswiki::ListIterator( \@iterators ) if scalar(@iterators) == 0;
    return $iterators[0] if scalar(@iterators) == 1;
    return new Foswiki::AggregateIterator( \@iterators );
}

# Expand %DATE% in a logfile name
sub _expandDATE {
    my ( $log, $time ) = @_;
    my $stamp = Foswiki::Time::formatTime( $time, '$year$mo', 'servertime' );
    $log =~ s/%DATE%/$stamp/go;
    return $log;
}

# Get the name of the log for a given reporting level
sub _getLogForLevel {
    my $level = shift;
    my $log;
    my $defaultLogDir = '';
    $defaultLogDir = "$Foswiki::cfg{DataDir}/" if $Foswiki::cfg{DataDir};

    foreach my $lvl (@$level) {
        if ( $lvl eq 'debug' ) {
            $log = $Foswiki::cfg{DebugFileName}
              || $defaultLogDir . 'debug%DATE%.txt';
        }
        elsif ( $lvl eq 'info' ) {
            $log = $Foswiki::cfg{LogFileName}
              || $defaultLogDir . 'log%DATE%.txt';
        }
        else {
            ASSERT( $lvl =~ /^(warning|error|critical|alert|emergency)$/ )
              if DEBUG;
            $log = $Foswiki::cfg{WarningFileName}
              || $defaultLogDir . 'warn%DATE%.txt';
        }
    }

    # SMELL: Expand should not be needed, except if bin/configure tries
    # to log to locations relative to $Foswiki::cfg{WorkingDir}, DataDir, etc.
    # Windows seemed to be the most difficult to fix - this was the only thing
    # that I could find that worked all the time.
    Foswiki::Configure::Load::expandValue($log);    # Expand in place

    return $log;
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
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
