use Test;
BEGIN { plan(tests => 1) }

ok(sub { eval("use Metabrik::Proxy::Http"); $@ ? 0 : 1 }, 1, $@);
