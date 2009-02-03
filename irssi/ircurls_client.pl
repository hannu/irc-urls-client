use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);
use strict;
use LWP;
use HTTP::Request::Common qw(POST);
use POSIX;

$VERSION = "0.02";
%IRSSI = (
    authors     => "IRC-URLs Team",
    name        => "ircurls_client",
    description => "IRC-URls v2 client",
    license     => "GPLv2"
);

my %urllog;
my $ua = LWP::UserAgent->new;
my $site_url = 'http://hannu.sivut.fi/submissions/create';

sub log_public {
    my ($server, $data, $nick, $mask, $target) = @_;
    return logurl($server->{chatnet}, $nick, $mask, $data, $target);
}
sub log_own{
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
    send_url($network, $nick, $mask, $url, $target);
    return 1;
  }
  return 0;
}

sub send_url {
  my ($network, $nick, $mask, $url, $target) = @_;
  my $site_client_key = Irssi::settings_get_str('ircurls_client_key');  
  my $pid = fork();
  if ($pid) {
    Irssi::pidwait_add($pid);
  } elsif (defined $pid) {
    my $req = POST $site_url, [
      url => $url, 
      network => $network,
      channel => $target,
      nick => $nick,
      mask => $mask,
      client_key => $site_client_key
    ];
    $ua->request($req);
    POSIX::_exit(1);
  } else {
    Irssi::print("IRC-URLs.net client: Fork error");
  }
  return 0;
}

# Irssi settings
Irssi::settings_add_str($IRSSI{'name'}, 'ircurls_client_key', '');

# Irssi signals
Irssi::signal_add_last('message public', 'log_public');
Irssi::signal_add_last('message own_public', 'log_own');
Irssi::signal_add_last('message topic', 'log_topic');

Irssi::print("IRC-URLs.net client " . $VERSION . " loaded");
