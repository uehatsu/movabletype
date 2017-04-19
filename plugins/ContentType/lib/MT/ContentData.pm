# Movable Type (r) (C) 2006-2016 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ContentData;

use strict;
use base qw( MT::Object );

use JSON ();

use MT;
use MT::Asset;
use MT::ContentField;
use MT::ContentType;
use MT::ObjectAsset;

use constant TAG_CACHE_TIME => 7 * 24 * 60 * 60;    ## 1 week

__PACKAGE__->install_properties(
    {   column_defs => {
            'id'              => 'integer not null auto_increment',
            'blog_id'         => 'integer not null',
            'status'          => 'smallint not null',
            'author_id'       => 'integer not null',
            'content_type_id' => 'integer not null',
            'data'            => 'blob',
        },
        indexes     => { content_type_id => 1 },
        defaults    => { status          => 0 },
        datasource  => 'cd',
        primary_key => 'id',
        audit       => 1,
        child_of    => ['MT::ContentType'],
    }
);

sub class_label {
    MT->translate("Content Data");
}

sub class_label_plural {
    MT->translate("Content Data");
}

sub to_hash {
    my $self = shift;
    my $hash = $self->SUPER::to_hash();
    $hash->{'cd.text_html'}
        = $self->_generate_text_html || $self->column('data');
    $hash;
}

sub _generate_text_html {
    my $self      = shift;
    my $data_hash = {};
    for my $field_id ( keys %{ $self->data } ) {
        my $field = MT::ContentField->load($field_id);
        my $hash_key = $field ? $field->name : "field_id_${field_id}";
        $data_hash->{$hash_key} = $self->data->{$field_id};
    }
    eval { JSON::to_json( $data_hash, { canonical => 1, utf8 => 1 } ) };
}

sub save {
    my $self = shift;

    my $content_field_types = MT->registry('content_field_types');
    my $content_type        = $self->content_type
        or return $self->error(
        MT->component('ContentType')->translate('Invalid content type') );

    $self->SUPER::save(@_) or return;

    my $field_data = $self->data;

    foreach my $f ( @{ $content_type->fields } ) {
        my $idx_type  = $f->{type};
        my $data_type = $content_field_types->{$idx_type}{data_type};
        my $value     = $field_data->{ $f->{id} };
        $value = [$value] unless ref $value eq 'ARRAY';

        if ( $idx_type eq 'asset' ) {
            $self->_save_asset_field_index( $content_type, $f, $value );
            next;
        }

        # next
        #     || $idx_type eq 'category'
        #     || $idx_type eq 'tag';

        MT::ContentFieldIndex->remove(
            {   content_type_id  => $content_type->id,
                content_data_id  => $self->id,
                content_field_id => $f->{id},
            }
        );

        for my $v (@$value) {
            my $cf_idx = MT::ContentFieldIndex->new;
            $cf_idx->set_values(
                {   content_type_id  => $content_type->id,
                    content_data_id  => $self->id,
                    content_field_id => $f->{id},
                }
            );

            $cf_idx->set_value( $data_type, $v )
                or return $self->error(
                MT->component('ContentType')->translate(
                    'Saving content field index failed: Invalid field type "[_1]"',
                    $data_type
                )
                );

            $cf_idx->save
                or return $self->error(
                MT->component('ContentType')->translate(
                    "Saving content field index failed: [_1]",
                    $cf_idx->errstr
                )
                );
        }
    }

    1;
}

sub _save_asset_field_index {
    my $self = shift;
    my ( $content_type, $field, $values ) = @_;

    MT::ObjectAsset->remove(
        {   object_ds => 'content_data',
            object_id => $self->id,
        }
    );

    for my $asset_id (@$values) {
        my $obj_asset = MT::ObjectAsset->new;
        $obj_asset->set_values(
            {   blog_id   => $self->blog_id,
                asset_id  => $asset_id,
                object_ds => 'content_data',
                object_id => $self->id
            }
        );
        $obj_asset->save or die $obj_asset->errstr;
    }
}

sub data {
    my $obj = shift;
    if (@_) {
        my %data = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
        my $json = eval { JSON::encode_json( \%data ) } || '{}';
        $obj->column( 'data', $json );
    }
    else {
        eval { JSON::decode_json( $obj->column('data') ) } || {};
    }
}

sub content_type {
    my $self = shift;
    $self->cache_property(
        'content_type',
        sub {
            MT::ContentType->load( $self->content_type_id || 0 ) || undef;
        },
    );
}

sub blog {
    my ($ct_data) = @_;
    $ct_data->cache_property(
        'blog',
        sub {
            my $blog_id = $ct_data->blog_id;
            require MT::Blog;
            MT::Blog->load($blog_id)
                or $ct_data->error(
                MT->translate(
                    "Loading blog '[_1]' failed: [_2]",
                    $blog_id,
                    MT::Blog->errstr
                        || MT->translate("record does not exist.")
                )
                );
        }
    );
}

sub terms_for_tags {
    return {};
}

sub get_tag_objects {
    my $obj = shift;
    $obj->__load_tags;
    return $obj->{__tag_objects};
}

sub __load_tags {
    my $obj = shift;
    my $t   = MT->get_timer;
    $t->pause_partial if $t;

    if ( !$obj->id ) {
        $obj->{__tags} = [];
        return $obj->{__tag_objects} = [];
    }
    return if exists $obj->{__tag_objects};

    require MT::Memcached;
    my $cache  = MT::Memcached->instance;
    my $memkey = $obj->tag_cache_key;
    my @tags;
    if ( my $tag_ids = $cache->get($memkey) ) {
        @tags = grep {defined} @{ MT::Tag->lookup_multi($tag_ids) };
    }
    else {
        require MT::ObjectTag;
        my $iter = MT::Tag->load_iter(
            undef,
            {   sort => 'name',
                join => [
                    'MT::ObjectTag',
                    'tag_id',
                    {   object_id         => $obj->id,
                        object_datasource => $obj->datasource
                    },
                    { unique => 1 }
                ],
            }
        );
        while ( my $tag = $iter->() ) {
            push @tags, $tag;
        }
        $cache->set( $memkey, [ map { $_->id } @tags ], TAG_CACHE_TIME );
    }
    $obj->{__tags} = [ map { $_->name } @tags ];
    $t->mark('MT::Tag::__load_tags') if $t;
    $obj->{__tag_objects} = \@tags;
}

sub tag_cache_key {
    my $obj = shift;
    return undef unless $obj->id;
    return sprintf "%stags-%d", $obj->datasource, $obj->id;
}

1;

