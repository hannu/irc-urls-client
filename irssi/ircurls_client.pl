use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);
use strict;
use POSIX;

use Fcntl;
use Errno;
use Socket;
use IO::Select;

$VERSION = "0.1.2";
%IRSSI = (
    authors     => "IRC-URLs Team",
    name        => "ircurls_client",
    description => "IRC-URls v2 client",
    license     => "GPLv2"
);

my %urllog;
my $site_host = 'beta.irc-urls.net';

my $last_message = "";
my $debug = 0;

sub log_public {
    my ($server, $data, $nick, $mask, $target) = @_;
    return logurl($server->{chatnet}, $nick, $mask, $data, $target);
}

sub debug_print {
  my $message = shift;
  if ($debug) { 
    Irssi::print("IRC-URLs.net client DEBUG: ".$message)
  }
}

sub error_print {
  my $message = shift;
  iIrssi::print("IRC-URLs.net client error: ".$message)
}

sub log_own {
    my ($server, $data, $target) = @_;
    # Parse !XXXXXchannel -> !channel
    if ($target =~ /\![A-Z0-9]{5}/) {
      $target = "!" . substr($target, 6);
    }
    # Find own hostmask
    my $mask = $server->channel_find($target)->nick_find($server->{nick})->{host};
    return logurl($server->{chatnet}, $server->{nick}, $mask, $data, $target);
}

sub log_topic {
    my ($server, $target, $data, $nick, $mask) = @_;
    return logurl($server->{chatnet}, $nick, $mask, $data, $target);
}

sub parse_url {
    my ($url) = @_;
    if ($url =~ /((http|https):\/\/\S+)/i) {
        return $1;
    } elsif($url =~ /(www\.\S+)/i){
        return "http://".$1;
    }
    return 0;
}

sub logurl {
  my ($network, $nick, $mask, $data, $target) = @_;
  my $url = parse_url($data); 
  if ($url) {
    nb_get($network, $nick, $mask, $url, $target);
    return 1;
  }
  return 0;
}

sub urlencode {
  my $str = shift;
  $str =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  return $str;
}

sub nb_get {
  my ($network, $nick, $mask, $url, $channel) = @_;
  
  my $postdata;
  $postdata  = "network=".urlencode($network)."&channel=".urlencode($channel);
  $postdata .= "&nick=".urlencode($nick)."&mask=".urlencode($mask);
  $postdata .= "&client_key=".urlencode(Irssi::settings_get_str('ircurls_client_key'));
  $postdata .= "&client=irssi&script_version=".urlencode($VERSION);
  $postdata .= "&url=" . urlencode($url);

  my $tmp;
  my $port = 80;
  my $socket;
  my $tag;

  local *SOCK;
  if (!socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
    error_print("Could not open socket");
    return nb_finisher($tag, $socket);
  }
  $socket = *SOCK;
  if (!defined($tmp = fcntl(SOCK, F_GETFL, 0))) {
    error_print("Could not get socket flags");
    return nb_finisher($tag, $socket);
  }
  if (!defined(fcntl(SOCK, F_SETFL, $tmp | O_NONBLOCK))) {
    error_print("Could not set non-blocking socket");
    return nb_finisher($tag, $socket);
  }
  # Look if we are allowed to fetch IP from cache
  $tmp = undef;
  if (!defined($tmp) || !($tmp)) {
    debug_print("Resolving dns...");
    $tmp = inet_aton($site_host);
  }
  if (!($tmp)) {
    error_print("Could not resolv submission url");
    return nb_finisher($tag, $socket);
  }
  # Check if url on port 80
  $tmp = sockaddr_in($port,$tmp);
  if (!connect(SOCK, $tmp)) {
    if ($! == EINPROGRESS) {
      debug_print("Connectíng...");
    } else {
      error_print("Error connecting to host" . $!);
      return nb_finisher();
    }
  }
  debug_print("Request sent, adding callback for socket");
  my @pargs = ($socket, \$tag, $postdata);
  $tag = Irssi::input_add(fileno($socket), INPUT_WRITE, \&nb_connected_get, \@pargs);
}

sub nb_connected_get {
  my ($socket, $tag, $postdata) = @{$_[0]};
  debug_print("Connected to server! Sending POST data...");
  # We have established a non blocking connection. Send request!
  
  Irssi::input_remove($$tag);
  my $tmp = select($socket); $|=1; select($tmp);

  $tmp = "POST /submissions/ HTTP/1.1\015\012";
  $tmp .= "Host: " . $site_host . "\015\012";
  $tmp .= "User-Agent: Irssi/Irc-urls-client\015\012";
  $tmp .= "Content-length: ".length($postdata)."\015\012".
    "Content-Type: application/x-www-form-urlencoded\015\012" if ($postdata);
  $tmp .= "Connection: close\015\012";
  $tmp .= "\015\012";
  $tmp .= $postdata if ($postdata);
  
  print $socket $tmp;
  debug_print("Data sent! Adding callback for reading...");
  my @pargs = ($socket, \$tag);
  $tag = Irssi::input_add(fileno($socket), INPUT_READ, \&nb_reader_get, \@pargs);
}
 
sub nb_reader_get {
  my ($socket, $tag) = @{$_[0]};
  # We have received non blocking data, read it and continue!
  debug_print("Data recieved!");
  Irssi::input_remove($$tag); # Don't disturb our reading
  return nb_finisher($socket, $tag);
}

sub nb_finisher {
  my ($socket, $tag) = @_;
  debug_print("Finished request");
  close($socket);
  $socket = undef;
  $tag = undef;
  return;
}

# Irssi settings
Irssi::settings_add_str($IRSSI{'name'}, 'ircurls_client_key', '');

# Irssi signals
Irssi::signal_add_last('message public', 'log_public');
Irssi::signal_add_last('message own_public', 'log_own');
Irssi::signal_add_last('message topic', 'log_topic');

Irssi::print("IRC-URLs.net client " . $VERSION . " loaded");
