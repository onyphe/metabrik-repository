use Test;
BEGIN { plan(tests => 2) }

ok(sub { eval("use Metabrik::Devel::Mercurial"); $@ ? 0 : 1 }, 1, $@);
ok(sub { eval("use Metabrik::Devel::Subversion"); $@ ? 0 : 1 }, 1, $@);
