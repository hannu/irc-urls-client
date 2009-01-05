use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);
use strict;
use LWP;
use HTTP::Request::Common qw(POST);
use POSIX;

$VERSION = "0.01";
%IRSSI = (
    authors     => "IRC-URLs Team",
    name        => "ircurls_client",
    description => "IRC-URls v2 client",
    license     => "GPLv2"
);

$SIG{CHLD}="IGNORE";

my %urllog;
my $ua = LWP::UserAgent->new;
my $site_url = 'http://hannu.sivut.fi/irc-urls/submissions/create';

sub log_public {
    my ($server, $data, $nick, $mask, $target) = @_;
    return logurl($server->{chatnet}, $nick, $mask, $data, $target);
}
sub log_own{
    my ($server, $data, $target) = @_;
    if(substr($target, 0, 1) eq "!") {
      $target = "!" . substr($target, 6);
    }
    # TODO: Get own host mask
    return logurl($server->{chatnet}, $server->{nick}, "own\@mask.foo", $data, $target);
}
sub log_topic {
    my ($server, $target, $data, $nick, $mask) = @_;
    return logurl($server->{chatnet}, $nick, $mask, $data, $target);
}
sub parse_url {
    my ($url) = @_;
    if ($url =~ /((http|https):\/\/[a-zA-Z0-9\|\[\]\/\\\:\?\%\.\,\&\;=#\-\_\!\+\~]*)/i){
        return $1;
    } elsif($url =~ /(www\.[a-zA-Z0-9\/\\\:\?\%\.\,\&\;=#\-\_\!\+\~]*)/i){
        return "http://".$1;
    }
    return 0;
}
sub logurl {
  my ($network, $nick, $mask, $data, $target) = @_;
  my $url = parse_url($data);
  if ($url) {
    # TODO: Use threads
    send_url($network, $nick, $mask, $url, $target);
  }
  return 0;
}

sub send_url {
  my ($network, $nick, $mask, $url, $target) = @_;
  my $site_user = Irssi::settings_get_str('ircurls_username');
  my $site_secret_key = Irssi::settings_get_str('ircurls_secret_key');
  Irssi::print("Sending: " . $site_user . " / ". $network." / ".$nick." / ".$mask." / ".$url." / ".$target);
  
  # Fork
  my $pid = fork();
  unless (defined $pid) {
    Irssi::print("Fork failed.");
    return;
  } elsif ($pid) {
    # parent
    Irssi::pidwait_add($pid);
    return;
  } else {
    # child
    my $req = POST $site_url, [
      url => $url, 
      network => $network,
      channel => $target,
      nick => $nick,
      mask => $mask,
      user => $site_user,
      secret_key => $site_secret_key
    ];
    
    $ua->request($req);
    POSIX::_exit(1);
  }
  return 0;
}

# Settings
Irssi::settings_add_str($IRSSI{'name'}, 'ircurls_username', '');
Irssi::settings_add_str($IRSSI{'name'}, 'ircurls_secret_key', '');

Irssi::signal_add_last('message public', 'log_public');
Irssi::signal_add_last('message own_public', 'log_own');
Irssi::signal_add_last('message topic', 'log_topic');
Irssi::print("IRC-URLs.net v2 client loaded");
