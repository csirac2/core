#!/usr/bin/perl -w
# TWikiTopic2TestCase.pl -
# Copyright 2004,2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

# TODO: add error checking!!!

use Getopt::Long;
use Pod::Usage;
use File::Basename;
use URI;
use Cwd qw( cwd );
use LWP::UserAgent::Foswiki::WikiGuest;
use WWW::Mechanize::TWiki 0.05;

my $Config = {

    #
    web    => 'GameDev',
    outweb => '',
    src    => "http://localhost/~twiki/cgi-bin/twiki",
    dest   => "http://localhost/~twiki/cgi-bin/twiki",
    agent  => basename($0),
    n      => undef,

    #
    verbose => 0,
    debug   => 0,
    help    => 0,
    man     => 0,
};

my $result = GetOptions(
    $Config,

    # test comparison options
    'web=s', 'outweb=s', 'src=s', 'dest=s', 'n=n',

    # miscellaneous/generic options
    'agent=s',
    'debug', 'help', 'man', 'verbose|v',
);
pod2usage(1) if $Config->{help};
pod2usage( { -exitval => 1, -verbose => 2 } ) if $Config->{man};
print Dumper($Config) if $Config->{debug};

my $srcMech = WWW::Mechanize::TWiki->new(
    agent     => $Config->{agent} . ' [src]',
    autocheck => 1
) or die $!;
$srcMech->cgibin( $Config->{src} );
$srcMech->pub("http://localhost/~twiki/htdocs/twiki");
my $destMech = WWW::Mechanize::TWiki->new(
    agent     => $Config->{agent} . ' [dest]',
    autocheck => 1
) or die $!;
$destMech->cgibin( $Config->{dest} );
$destMech->pub("http://localhost/~twiki/htdocs/twiki");

$Config->{outweb} ||= $Config->{web} . 'testcases';

################################################################################

# unless webExists({ web => $Config->{outweb} })
$destMech->view("System.ManagingWebs");
$destMech->submit_form(
    form_name => 'admin',
    fields    => {
        newweb     => $Config->{outweb},
        baseweb    => '_default',          # empty!
        webbgcolor => '#FF0099',           # hot pink (noticeable!)
        sitemapwhat  => 'TWiki Automated Unit and Regression Tests',
        sitemapuseto => '...internal testing',

        #		nosearchall => 'off',
    },
) or die $!;

################################################################################

my @topics = grep { !/^Web/ } $srcMech->getPageList( $Config->{web} );
print Dumper( \@topics ) if $Config->{debug};
die "no topics in $Config->{web}?" unless @topics;
for ( my $i = 0 ; $i < scalar @topics ; ++$i ) {
    last if defined $Config->{n} and $i >= $Config->{n};
    my $iTopic = $topics[$i];
    print STDERR "$Config->{web}.$iTopic\n" if $Config->{verbose};
    TWikiTopic2TestCase(
        {
            topic                  => "$Config->{web}.${iTopic}",
            outweb                 => $Config->{outweb},
            topic_name_without_web => $iTopic,
            %$Config
        }
    );
}

exit 0;

################################################################################
################################################################################

# topic: (fully qualified) topic name (including webname component)
sub TWikiTopic2TestCase {
    my $parms  = shift;
    my $topic  = $parms->{topic};
    my $outweb = $parms->{outweb};
    my $iTopic = $parms->{topic_name_without_web};  # this is a temporary kludge

    # grab html
    my $htmlGoldenExpected =
      $srcMech->view( $topic, { skin => 'text' } )->content();

    # grab raw tml text
    my $tmlTextSource =
      $srcMech->view( $topic, { skin => 'text', raw => 1 } )->content();

    # create new topic in UnitCases
    $destMech->edit("$outweb.$iTopic");

    ################################################################################
    # make the new TestCase topic
    my $testCaseTemplate = <<__TEMPLATE__;
---+!! %TOPIC%

Description: generated by =$Config->{agent}= from $topic

Expected
<!-- expected -->
$htmlGoldenExpected
<!-- /expected -->

Source
<!-- actual -->
$tmlTextSource
<!-- /actual -->
__TEMPLATE__

    $destMech->field( text => $testCaseTemplate );
    $destMech->click_button( value => 'Save' );

    # attachments
    my $uaAttachment =
      LWP::UserAgent::Foswiki::WikiGuest->new( agent => $Config->{agent} )
      or die $!;
    my @attachments = $srcMech->getAttachmentsList($topic);
    foreach my $attachment (@attachments) {
        print $attachment->{_filename}, "\n" if $parms->{verbose};
        print Dumper($attachment) if $parms->{debug};

        $uaAttachment->mirror( $attachment->{Attachment},
            $attachment->{_filename} )
          or warn $!;
        warn "$attachment->{_filename} missing\n", next
          unless -e $attachment->{_filename};
        $destMech->attach("$outweb.$iTopic") or die $!;
        $destMech->submit_form(    # 'Upload file'
            fields => {
                filepath    => $attachment->{_filename},
                filecomment => $attachment->{Comment},

                #					   hidefile => 'on',
                hidefile => $attachment->{Attribute} =~ /h/ ? 'on' : 'off',
            },
        ) or die $!;
        unlink $attachment->{_filename} or die $!;
    }
}

################################################################################
################################################################################
__DATA__

=head1 NAME

TWikiTopic2TestCase.pl - ...

=head1 SYNOPSIS

test.pl [options] [-web=]

Copyright 2004 Will Norris.  All Rights Reserved.

 Options:
   -web=			...
   -outweb=         ...
   -src=              ...
   -dest=
   -n=
   -agent=
   -verbose
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=item B<-web>

=back

=head1 DESCRIPTION

B<TWikiTopic2TestCase.pl> will ...

=head2 SEE ALSO

  http://twiki.org/cgi-bin/view/Codev/...

=cut
