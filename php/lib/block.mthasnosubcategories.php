<?php
# Movable Type (r) (C) 2001-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

require_once("block.mthassubcategories.php");
function smarty_block_mthasnosubcategories($args, $content, &$ctx, &$repeat) {
    if (!isset($content)) {
        $has_no_sub_cats = !_has_sub_categories($ctx);
        return $ctx->_hdlr_if($args, $content, $ctx, $repeat, $has_no_sub_cats);
    } else {
        return $ctx->_hdlr_if($args, $content, $ctx, $repeat);
    }
}
?>
