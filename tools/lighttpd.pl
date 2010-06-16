#!/usr/bin/perl

use strict;
use File::Basename;
use File::Spec;
use Cwd;

# defaults
my $PORT = 8080;

# calculate paths
my $foswiki_core = Cwd::abs_path( File::Spec->catdir( dirname(__FILE__), '..' ) );
chomp $foswiki_core;
my $conffile = $foswiki_core . '/working/tmp/lighttpd.conf';

my $mime_mapping=q(include_shell "/usr/share/lighttpd/create-mime.assign.pl");
if( ! -e  "/usr/share/lighttpd/create-mime.assign.pl" ) {
$mime_mapping = q(mimetype.assign             = \(
  ".rpm"          =>      "application/x-rpm",
  ".pdf"          =>      "application/pdf",
  ".sig"          =>      "application/pgp-signature",
  ".spl"          =>      "application/futuresplash",
  ".class"        =>      "application/octet-stream",
  ".ps"           =>      "application/postscript",
  ".torrent"      =>      "application/x-bittorrent",
  ".dvi"          =>      "application/x-dvi",
  ".gz"           =>      "application/x-gzip",
  ".pac"          =>      "application/x-ns-proxy-autoconfig",
  ".swf"          =>      "application/x-shockwave-flash",
  ".tar.gz"       =>      "application/x-tgz",
  ".tgz"          =>      "application/x-tgz",
  ".tar"          =>      "application/x-tar",
  ".zip"          =>      "application/zip",
  ".mp3"          =>      "audio/mpeg",
  ".m3u"          =>      "audio/x-mpegurl",
  ".wma"          =>      "audio/x-ms-wma",
  ".wax"          =>      "audio/x-ms-wax",
  ".ogg"          =>      "application/ogg",
  ".wav"          =>      "audio/x-wav",
  ".gif"          =>      "image/gif",
  ".jar"          =>      "application/x-java-archive",
  ".jpg"          =>      "image/jpeg",
  ".jpeg"         =>      "image/jpeg",
  ".png"          =>      "image/png",
  ".xbm"          =>      "image/x-xbitmap",
  ".xpm"          =>      "image/x-xpixmap",
  ".xwd"          =>      "image/x-xwindowdump",
  ".css"          =>      "text/css",
  ".html"         =>      "text/html",
  ".htm"          =>      "text/html",
  ".js"           =>      "text/javascript",
  ".asc"          =>      "text/plain",
  ".c"            =>      "text/plain",
  ".cpp"          =>      "text/plain",
  ".log"          =>      "text/plain",
  ".conf"         =>      "text/plain",
  ".text"         =>      "text/plain",
  ".txt"          =>      "text/plain",
  ".dtd"          =>      "text/xml",
  ".xml"          =>      "text/xml",
  ".mpeg"         =>      "video/mpeg",
  ".mpg"          =>      "video/mpeg",
  ".mov"          =>      "video/quicktime",
  ".qt"           =>      "video/quicktime",
  ".avi"          =>      "video/x-msvideo",
  ".asf"          =>      "video/x-ms-asf",
  ".asx"          =>      "video/x-ms-asf",
  ".wmv"          =>      "video/x-ms-wmv",
  ".bz2"          =>      "application/x-bzip",
  ".tbz"          =>      "application/x-bzip-compressed-tar",
  ".tar.bz2"      =>      "application/x-bzip-compressed-tar",
  # default mime type
  ""              =>      "application/octet-stream",
 \)) ;
}

# write configuration file
open(CONF, '>', $conffile) or die("!! Cannot write configuration. Check write permissions to $conffile!");
print CONF "server.document-root = \"$foswiki_core\"\n";
print CONF  <<EOC
server.modules = (
   "mod_rewrite",
   "mod_cgi"
)
server.port = $PORT

server.errorlog = "/scratch/foswiki/core/working/tmp/error.log"

# mimetype mapping
$mime_mapping

url.rewrite-repeat = ( "^/?(index.*)?\$" => "/bin/view/Main" )
\$HTTP["url"] =~ "^/bin" { cgi.assign = ( "" => "" ) }
EOC
;;
close(CONF);

# print banner
print "************************************************************\n";
print "Foswiki Development Server\n";
system('/usr/sbin/lighttpd -v 2>/dev/null');
print "Server root: $foswiki_core\n";
print "************************************************************\n";
print "Browse to http://localhost:$PORT/bin/configure to configure your Foswiki\n";
print "Browse to http://localhost:$PORT/bin/view to start testing your Foswiki checkout\n";
print "Hit Control-C at any time to stop\n";
print "************************************************************\n";


# execute lighttpd
system("/usr/sbin/lighttpd -f $conffile -D");

# finalize
system("rm -rf $conffile");
