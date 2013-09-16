package SortCatFldMover::ContextHandlers;

use strict;
use MT;
use MT::Template::Context;

# MTSortedTopLevelCategories tag
sub sorted_top_level_categories {
    my ($ctx, $args, $cond) = @_;
    $ctx->invoke_handler('toplevelcategories', $args, $cond);
}

# MTSortedSubCategories tag
sub sorted_sub_categories {
    my ($ctx, $args, $cond) = @_;
    $ctx->invoke_handler('subcategories', $args, $cond);
}

# MTSortedTopLevelFolders tag
sub sorted_top_level_folders {
    my ($ctx, $args, $cond) = @_;
    $ctx->invoke_handler('toplevelfolders', $args, $cond);
}

# MTSortedSubFolders tag
sub sorted_sub_folders {
    my ($ctx, $args, $cond) = @_;
    $ctx->invoke_handler('subfolders', $args, $cond);
}

# MTSortedCategoryPrevious tag
# MTSortedCategoryNext tag
sub sorted_category_prev_next {
    my ($ctx, $args, $cond) = @_;

    my $tag = lc $ctx->stash('tag');
    if (!$args->{no_skip}) {
        $tag =~ s/sorted//;
        return $ctx->invoke_handler($tag, $args, $cond);
    }

    my $res = '';
    my $cat = $ctx->stash('category') || $ctx->stash('archive_category');
    if ($cat) {
        # initialize
        my $direction = ($tag =~ /sorted(category|folder)previous/)
                        ? -1 : 1;
        my $class = MT->model($cat->class);
        my $blog = $ctx->stash('blog');

        # get sibling cats
        my $sorted_cats = _load_sorted_cats($blog, $cat->class);
        my $req = MT::Request->instance;
        my $sib_cats = $req->stash('SortCatFldMover::SibCats::' . $class . '::' . $blog->id . '::' . $cat->id);
        my $cat_positions = $req->stash('SortCatFldMover::CatPositions::' . $class . '::' . $blog->id . '::' . $cat->id);
        unless (defined($sib_cats)) {
            my @sib_cats = $class->load({
                               blog_id => $cat->blog_id,
                               parent => $cat->parent,
                           });
            @sib_cats = sort { $sorted_cats->{$a->id} <=>
                               $sorted_cats->{$b->id} } @sib_cats;
            $sib_cats = \@sib_cats;
            my $cat_pos = 0;
            $cat_positions = {};
            foreach (@sib_cats) {
                $cat_positions->{$_->id} = $cat_pos;
                $cat_pos++;
            }
            foreach (@sib_cats) {
                $req->stash('SortCatFldMover::SibCats::' . $class . '::' . $blog->id . '::' . $_->id, $sib_cats);
                $req->stash('SortCatFldMover::CatPositions::' . $class . '::' . $blog->id . '::' . $_->id, $cat_positions);
            }
        }

        # get adjacent category
        my $pos = $cat_positions->{$cat->id};
        $pos += $direction;
        if ($pos >= 0 && $pos < scalar @$sib_cats) {
            # out category
            my $adj_cat = $sib_cats->[$pos];
            my $tok = $ctx->stash('tokens');
            my $builder = $ctx->stash('builder');
            local $ctx->{__stash}->{category} = $adj_cat;
            my $out = $builder->build($ctx, $tok, $cond);
            return $ctx->error($builder->errstr) unless defined $out;
            $res .= $out;
        }
    }
    return $res;
}

# MTSortedFolderPrevious tag
# MTSortedFolderNext tag
sub sorted_folder_prev_next {
    my ($ctx, $args, $cond) = @_;
    return undef unless MT::Template::Tags::Folder::_check_folder($ctx, $args, $cond);
    &sorted_category_prev_next(@_);
}

# MTSortedEntryCategories tag
sub sorted_entry_categories {
    my ($ctx, $args, $cond) = @_;

    my $entry = $ctx->stash('entry')
        or return $ctx->_no_entry_error();
    my $cats = $entry->categories;
    return '' if (!$cats);

    # load sorted categories
    my $blog = $ctx->stash('blog');
    my $sorted_cats = _load_sorted_cats($blog, 'category');

    # sort and grep categories
    my $pri_cat = $entry->category;
    if ($args->{exclude_primary} || $args->{primary_first} || $args->{primary_last}) {
        @$cats = grep { $_->id != $pri_cat->id } @$cats;
    }
    @$cats = sort { $sorted_cats->{$a->id} <=>
                    $sorted_cats->{$b->id} } @$cats;
    if ($args->{primary_first} && !$args->{exclude_primary} && $pri_cat) {
        unshift @$cats, $pri_cat;
    }
    elsif ($args->{primary_last} && !$args->{exclude_primary} && $pri_cat) {
        push @$cats, $pri_cat;
    }

    # out
    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my @res = ();
    my $entry_class = MT->model('entry');
    my $glue = $args->{glue} || '';
    my $vars = $ctx->{__stash}{vars} ||= {};
    local $vars->{__size__} = scalar(@$cats);
    my $i = 0;

    if (scalar @$cats) {
        for my $cat (@$cats) {
            local $ctx->{inside_mt_categories} = 1;
            local $ctx->{__stash}->{category} = $cat;
            local $vars->{__primary__} = ($cat->id == $pri_cat->id);
            local $vars->{__order__} = $sorted_cats->{$cat->id};
            local $vars->{__first__} = !$i;
            local $vars->{__last__} = !defined $cats->[$i + 1];
            local $vars->{__odd__} = ($i % 2) == 0;
            local $vars->{__even__} = ($i % 2) == 1;
            local $vars->{__counter__} = $i + 1;
            defined(my $out = $builder->build($ctx, $tokens, $cond))
                or return $ctx->error($builder->errstr);
            push @res, $out;
            $i++;
        }
        return join $glue, @res;
    }
    else {
        return $ctx->else($args, $cond);
    }
}

sub _load_sorted_cats {
    my ($blog, $class) = @_;
    my $req = MT::Request->instance;

    my $sorted_cats = $req->stash('SortCatFldMover::SortedCats::' . $class . '::' . $blog->id);
    unless (defined($sorted_cats)) {
        my $order = 1;
        my @blog_cat_order_a = split ',', $blog->category_order;
        for (my $i = 0; $i < scalar(@blog_cat_order_a); $i++) {
            $sorted_cats->{$blog_cat_order_a[$i]} = $i;
        }
        $req->stash('SortCatFldMover::SortedCats::' . $class . '::' . $blog->id, $sorted_cats);
    }
    return $sorted_cats;
}

1;
