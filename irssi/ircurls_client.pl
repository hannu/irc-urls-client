use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);
use strict;
use LWP;
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
my $browser = LWP::UserAgent->new;
my $site_url = 'http://hannu.sivut.fi/irc-urls/submissions/create';
my $site_user = 'test-logger'
my $site_secret_key = 'b64037fc00993be74d67d92544fa52abceca0f56'

sub log_public {
    my ($server, $data, $nick, $mask, $target) = @_;
    return logurl($server->{chatnet}, $nick, $mask, $data, $target);
}
sub log_own{
    my ($server, $data, $target) = @_;
    return logurl($server->{chatnet}, $server->{nick}, $server->{mask}, $data, $target);
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
  $browser->post($site_url,
    [
      url => $url, 
      network => $network,
      nick => $nick,
      mask => $mask,
      user => $site_user
      secret_key => 
    ]
  );
  return 0;
}

Irssi::signal_add_last('message public', 'log_public');
Irssi::signal_add_last('message own_public', 'log_own');
Irssi::signal_add_last('message topic', 'log_topic');
Irssi::print("IRC-URLs.net v2 client loaded");
