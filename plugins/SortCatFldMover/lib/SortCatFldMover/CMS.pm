package SortCatFldMover::CMS;

use strict;
use MT;
use MT::Blog;
use MT::Website;
use MT::Util qw( encode_js );

sub init_app {
    my $app = shift;
    my $plugin = MT->component('SortCatFldMover');
    bless $plugin, 'MT::Plugin::SortCatFldMover';
}

sub move_start {
    my $app = shift;
    my $plugin = MT->component('SortCatFldMover');
    my %param;

    if ($app->param('id')) {
        my @blog_ids = $app->param('id');
        $param{blog_ids} = join ',', @blog_ids;
        $param{count} = scalar @blog_ids;
    }
    else {
        # load all websites and blogs
        my @blogs = MT->model('blog')->load({ class => [ 'blog', 'website' ] });
        $param{blog_ids} = join ',', (map { $_->id } @blogs);
        $param{count} = scalar @blogs;
    }
    $param{offset} = 0;
    my $tmpl = $plugin->load_tmpl('move_start.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    return $app->build_page($tmpl, \%param);
}

sub select_blogs {
    my $app = shift;
    my $plugin = MT->component('SortCatFldMover');
    my %param;

    # check permission
    my $user = $app->user
        or return $app->error($plugin->translate('Load user error'));
    return $app->error($plugin->translate('You are not an administrator.'))
        unless ($user->is_superuser);

    # set data
    my @data;
    my $odd = 0;
    my @websites = MT->model('website')->load;
    for my $website (@websites) {
        push @data, {
            id => $website->id,
            name => $website->name ? $website->name : $plugin->translate('No name'),
            description => $website->description,
            odd => $odd,
            is_blog => 0,
        };
        $odd = !$odd;
        my @blogs = MT->model('blog')->load(
                        {
                            parent_id => $website->id
                        },
                        {
                            sort => 'name',
                            direction => 'ascend',
                        }
                    );
        for my $blog (@blogs) {
            push @data, {
                id => $blog->id,
                name => $blog->name ? $blog->name : $plugin->translate('No name'),
                description => $blog->description,
                odd => $odd,
                is_blog => 1,
            };
            $odd = !$odd;
        }
    }
    $param{position_actions_top} = 1;
    $param{limit_none} = 1;
    $param{empty_message} = $plugin->translate('No websites / blogs found.');
    $param{listing_screen} = 1;
    $param{object_loop}         = \@data;
    $param{object_label}        = $plugin->translate('Website / Blog');
    $param{object_label_plural} = $plugin->translate('Websites / Blogs');
    $param{object_type}         = 'blog';

    # show page
    my $tmpl = $plugin->load_tmpl('select_blogs.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    $app->build_page($tmpl, \%param);
}

sub move {
    my $app = shift;
    my $plugin = MT->component('SortCatFldMover');
    my %param;

    my $blog;
    eval {
        my $blog_id = $app->param('blog_id');
        $blog = MT->model('blog')->load($blog_id) ||
                MT->model('website')->load($blog_id);
        my @classes = ($blog->is_blog)
                    ? qw( category folder ) : qw( folder );
        for my $class (@classes) {
            my @cats = MT->model($class)->load(
                           { blog_id => $blog_id },
                           { sort => 'label', direction => 'ascend' }
                       );
            my $order_number = scalar @cats + 1;
            @cats = map {
                unless ($_->order_number) {
                    $_->order_number($order_number);
                    $order_number++;
                }
                $_;
            } @cats;
            @cats = sort { $a->order_number <=> $b->order_number} @cats;
            $blog->meta($class . '_order', join ',', (map { $_->id } @cats));
        }
        $blog->save;
    };
    my $json = '{"blog_name":"' . encode_js($blog->name) . '",';
    $json .= '"is_blog":' . ($blog->is_blog ? '1' : '0') . ",";
    if ($@) {
        $json .= '"error":"' . encode_js($@) . '"}';
    }
    else {
        $json .= '"ok":1}'
    }

    $app->send_http_header("application/json");
    $app->{no_print_body} = 1;
    $app->print_encode($json);
    return undef;
}

package MT::Plugin::SortCatFldMover;

use MT::Plugin;
use MT::Blog;
use base qw( MT::Plugin );

sub load_config {
    my ($plugin, $param, $scope) = @_;

    $plugin->SUPER::load_config($param, $scope);
    return if ($scope eq 'system');

    my $app = MT->instance;
    my $blog = $app->blog;
    $param->{fjscfm_blog_id} = $blog->id;
    $param->{fjscfm_is_blog} = 1 if $blog->is_blog;
}

1;
