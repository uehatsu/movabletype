package MT::Test::Selenium;

use strict;
use warnings;
use Test::TCP;
use Plack::Runner;
use Plack::Builder;
use File::Spec;
use File::Which qw/which/;
use URI;
use JSON::PP;  # silence redefine warnings
use MT::PSGI;
use constant DEBUG => $ENV{MT_TEST_SELENIUM_DEBUG} ? 1 : 0;

our %EXTRA = (
    "Selenium::Chrome" => {
        chromeOptions => {
            args => [
                'headless', ( DEBUG ? 'enable-logging' : () ),
                'window-size=1280,800', 'no-sandbox',
            ],
        },
        binaries =>
            [ 'chromedriver', '/usr/lib/chromium-browser/chromedriver', ],
    },
    "Selenium::Remote::Driver" => {
        chromeOptions => {
            args => [
                'headless', ( DEBUG ? 'enable-logging' : () ),
                'window-size=1280,800', 'no-sandbox',
            ],
        },
    },
);

sub new {
    my ( $class, $env ) = @_;
    my $server = Test::TCP->new(
        code => sub {
            my $port = shift;

            $env->update_config(
                CGIPath => "http://127.0.0.1:$port/cgi-bin/",
            );

            my $app     = MT::PSGI->new->to_app;
            my $builder = builder {
                enable 'AccessLog' if DEBUG;
                $app;
            };
            my $runner = Plack::Runner->new( app => $builder );
            $runner->parse_options(
                '--port'   => $port,
                '--env'    => ( DEBUG ? 'development' : 'test' ),
                '--server' => 'Standalone',
            );
            $runner->run;
        },
    );

    my $driver_class = $ENV{MT_TEST_SELENIUM_DRIVER}
        || ( $ENV{TRAVIS} ? 'Selenium::Remote::Driver' : 'Selenium::Chrome' );
    eval "require $driver_class";

    my $extra = $EXTRA{$driver_class} || {};

    my %driver_opts = (
        auto_close          => 1,
        default_finder      => 'css',
        extra_capabilities  => $extra,
        acceptInsecureCerts => 1,
        timeout             => 10,
        port                => 9515,
    );
    for my $binary ( @{ delete $extra->{binaries} || [] } ) {
        $binary = _fix_binary($binary) or next;
        $driver_opts{binary} = $binary;
        last;
    }

    if (DEBUG) {
        my $log_file = "$ENV{MT_HOME}/selenium_log.txt";
        $driver_opts{custom_args} = "--log-path=$log_file --verbose";
    }

    my $driver = $driver_class->new(%driver_opts);

    $driver->debug_on if DEBUG;

    my $port     = $server->port;
    my $base_url = URI->new("http://127.0.0.1:$port");

    bless {
        server   => $server,
        base_url => $base_url,
        driver   => $driver,
        pid      => $$,
    }, $class;
}

sub _fix_binary {
    my $binary = shift;
    if ( File::Spec->file_name_is_absolute($binary) ) {
        return $binary if -e $binary && -x _;
    }
    else {
        which($binary);
    }
}

sub driver { shift->{driver} }

sub DESTROY {
    my $self = shift;
    return unless $self->{pid} eq $$;
    my $driver = $self->{driver} or return;
    $driver->quit;
}

# The following methods are just to keep compatibility with Test::Wight

sub visit {
    my ( $self, $path_query ) = @_;
    my $url = $self->{base_url}->clone;
    $url->path_query($path_query);
    $self->driver->get( $url->as_string );
    $self;
}

sub find {
    my ( $self, $selector ) = @_;
    my $element = eval { $self->driver->find_element($selector); };
    $self->{_element} = $element;
    $self;
}

sub value {
    my $self = shift;
    my $element = $self->{_element} or return;
    $element->get_value;
}

sub attribute {
    my ( $self, $attr ) = @_;
    my $element = $self->{_element} or return;
    $element->get_attribute($attr);
}

sub set {
    my ( $self, $value ) = @_;
    my $element = $self->{_element} or return;
    $element->clear;
    $element->send_keys("$value");
}

1;
