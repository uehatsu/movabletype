#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib"; # t/lib
use Test::More;
use MT::Test::Env;
our $test_env;
BEGIN {
    $test_env = MT::Test::Env->new;
    $ENV{MT_CONFIG} = $test_env->config_file;
}

use IPC::Open2;

use Test::Base;
plan tests => 2 * blocks;

use MT;
use MT::Test;
use MT::Test::Permission;
my $app = MT->instance;

$test_env->prepare_fixture('db');

my $blog_id = 1;

filters {
    template => [qw( chomp )],
    expected => [qw( chomp )],
};

my $mt = MT->instance;

my $blog = MT::Blog->load($blog_id);
$blog->archive_type('Page');
$blog->save or die $blog->errstr;

my $page = MT::Test::Permission->make_page( blog_id => $blog_id );

run {
    my $block = shift;

SKIP:
    {
        skip $block->skip, 1 if $block->skip;

        my $tmpl = $app->model('template')->new;
        $tmpl->type('index');
        $tmpl->text( $block->template );
        my $ctx = $tmpl->context;

        my $blog = MT::Blog->load($blog_id);
        $ctx->stash( 'blog',          $blog );
        $ctx->stash( 'blog_id',       $blog->id );
        $ctx->stash( 'local_blog_id', $blog->id );
        $ctx->stash( 'builder',       MT::Builder->new );

        my $result = $tmpl->build;
        $result =~ s/^(\r\n|\r|\n|\s)+|(\r\n|\r|\n|\s)+\z//g;

        is( $result, $block->expected, $block->name );
    }
};

sub php_test_script {
    my ( $template, $text ) = @_;
    $text ||= '';

    my $test_script = <<PHP;
<?php
\$MT_HOME   = '@{[ $ENV{MT_HOME} ? $ENV{MT_HOME} : '.' ]}';
\$MT_CONFIG = '@{[ $app->find_config ]}';
\$blog_id   = '$blog_id';
\$tmpl = <<<__TMPL__
$template
__TMPL__
;
\$text = <<<__TMPL__
$text
__TMPL__
;
PHP
    $test_script .= <<'PHP';
include_once($MT_HOME . '/php/mt.php');
include_once($MT_HOME . '/php/lib/MTUtil.php');

$mt = MT::get_instance(1, $MT_CONFIG);
$mt->init_plugins();

$db = $mt->db();
$ctx =& $mt->context();

$ctx->stash('blog_id', $blog_id);
$ctx->stash('local_blog_id', $blog_id);
$blog = $db->fetch_blog($blog_id);
$ctx->stash('blog', $blog);

if ($ctx->_compile_source('evaluated template', $tmpl, $_var_compiled)) {
    $ctx->_eval('?>' . $_var_compiled);
} else {
    print('Error compiling template module.');
}

?>
PHP
}

SKIP:
{
    unless ( join( '', `php --version 2>&1` ) =~ m/^php/i ) {
        skip "Can't find executable file: php",
            1 * blocks('expected_dynamic');
    }

    run {
        my $block = shift;

    SKIP:
        {
            skip $block->skip, 1 if $block->skip;

            open2( my $php_in, my $php_out, 'php -q' );
            print $php_out &php_test_script( $block->template, $block->text );
            close $php_out;
            my $php_result = do { local $/; <$php_in> };
            $php_result =~ s/^(\r\n|\r|\n|\s)+|(\r\n|\r|\n|\s)+\z//g;

            my $name = $block->name . ' - dynamic';
            is( $php_result, $block->expected, $name );
        }
    };
}

__END__

=== MTArchiveFile
--- template
<MTArchiveList type="Page"><MTArchiveFile>
</MTArchiveList>
--- expected
watching_the_river_flow.html
