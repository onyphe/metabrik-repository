use Test;
BEGIN { plan(tests => 26) }

ok(sub { eval("Metabricky::Brick::Address::Netmask");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Audit::Dns");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Core::Template");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Crypto::Aes");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Database::Cwe");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Database::Keystore");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Database::Nvd");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Database::Sqlite");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Database::Vfeed");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Encode::Base64");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::File::Fetch");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::File::Find");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::File::Slurp");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::File::Zip");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Http::Proxy");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Http::Www");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Http::Wwwutil");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Identify::Ssh");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Netbios::Name");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Network::Frame");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Remote::Ssh2");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Server::Agent");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Shell::Meby");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::Ssdp::Ssdp");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::System::Arp");   $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("Metabricky::Brick::System::Route");   $@ ? 0 : 1 }, 1, $@);
