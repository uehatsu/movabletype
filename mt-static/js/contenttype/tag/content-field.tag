<content-field id="content-field-block-{ id }">
  <div class="mt-collapse__container">
    <div class="col-auto"><svg title="{ trans('Move') }" role="img" class="mt-icon"><use xlink:href="{ StaticURI }/images/sprite.svg#ic_move" /></svg></div>
    <div class="col"><svg title="{ trans('ContentField') }" role="img" class="mt-icon--secondary"><use xlink:href="{ StaticURI }images/sprite.svg#ic_contentstype" /></svg>{ label } ({ typeLabel })</div>
    <div class="col-auto">
      <a href="javascript:void(0)" onclick={ deleteField }><svg title="{ trans('Delete') }" role="img" class="mt-icon--secondary"><use xlink:href="{ StaticURI }images/sprite.svg#ic_trash" /></svg></a>
      <a data-toggle="collapse" href="#field-options-{ id }" aria-expanded="{ isShow == 'show' ? 'true' : 'false' }" aria-controls="field-options-{ id }"><svg title="{ trans('Edit') }" role="img" class="mt-icon--secondary"><use xlink:href="{ StaticURI }images/sprite.svg#ic_collapse" /></svg></a>
    </div>
  </div>
  <div data-is={ type } class="collapse mt-collapse__content  { isShow }" id={ 'field-options-' + id } fieldid={ id } options={ this.options } isnew={ isNew }></div>

  <script>
    deleteField(e) {
      item = e.item
      index = this.parent.fields.indexOf(item)
      this.parent.fields.splice(index, 1)
      this.parent.update({
        isEmpty: this.parent.fields.length > 0 ? false : true
      })
      var target = document.getElementsByClassName('mt-draggable__area')[0]
      this.parent.recalcHeight(target)

    }
  </script>
</content-field>
