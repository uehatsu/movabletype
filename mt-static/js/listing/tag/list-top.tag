<list-top>
  <div class="d-none d-md-block mb-3" data-is="display-options"></div>
  <div class="row mb-3">
    <virtual data-is="list-actions"
      if={ opts.useActions }
    ></virtual>
  </div>
  <div class="row mb-3">
    <div class="col-12">
      <div class="card">
        <virtual data-is="list-filter"
          if={ opts.useFilters }
        >
        </virtual>
        <table data-is="list-table"
          id="{ opts.objectType }-table"
          class="table mt-table { tableClass() }"
        >
        </table>
      </div>
    </div>
  </div>
  <div class="row" hide={ opts.store.count == 0 }>
    <virtual data-is="list-pagination"></virtual>
  </div>

  <script>
    riot.mixin('listTop', {
      init: function () {
        if (this.__.tagName == 'list-top') {
          this.listTop = this
          this.store = opts.store
        } else {
          this.listTop = this.parent.listTop
          this.store = this.parent.store
        }
      }
    })
    this.mixin('listTop')

    var self = this

    opts.store.on('refresh_view', function (args) {
      if (!args) args = {}
      var moveToPagination = args.moveToPagination
      var notCallListReady = args.notCallListReady

      self.update()
      self.updateSubFields()
      if (moveToPagination) {
        window.document.body.scrollTop = window.document.body.scrollHeight
      }
      if (!notCallListReady) {
        jQuery(window).trigger('listReady')
      }
    })

    this.on('mount', function () {
      this.opts.store.trigger('load_list')
    })

    updateSubFields() {
      opts.store.columns.forEach(function (column) {
        column.sub_fields.forEach(function (subField) {
          var selector = 'td.' + subField.parent_id + ' .' + subField.class
          if (subField.checked) {
            jQuery(selector).show()
          } else {
            jQuery(selector).hide()
          }
        })
      })
    }

    tableClass() {
      var objectType = opts.objectTypeForTableClass || opts.objectType
      return 'list-' + objectType
    }

    isMobileView() {
      return jQuery(window).width() < 768
    }
   </script>
</list-top>
