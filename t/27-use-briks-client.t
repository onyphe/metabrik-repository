use Test;
BEGIN { plan(tests => 14) }

ok(sub { eval("use Metabrik::Client::Dns"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Elasticsearch"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Openssh"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Rest"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Rsync"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Splunk"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Ssh"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Ssl"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Tcp"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Tcpdump"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Twitter"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Udp"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Whois"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Client::Www"); $@ ? 0 : 1 }, 1, $@);
