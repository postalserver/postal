(function ($) {

  'use strict';

  function Multibox($el, options) {
    this.$el = $el;
    this.options = options;
    this.draw();
    this.listen();
  }

  Multibox.prototype.destroy = function destroy() {
    this.$inputs.off();
    this.$el.detach();
    this.$container.replaceWith(this.$el);

    if (this.previousType) {
      this.$el.attr('type', this.previousType);
    }
  };

  Multibox.prototype.draw = function draw() {
    var classNames = this.options.classNames;
    var inputAutofocus = this.$el.attr('autofocus');
    var inputType = this.$el.attr('type');
    var inputValue = this.$el.val();

    var focusIndex;
    var inputIndex;
    var text;

    if (inputType !== 'hidden') {
      this.previousType = inputType;
      this.$el.attr('type', 'hidden');
    }

    this.$container = $('<div />', {
      'class': classNames.container
    });

    var size = Array.apply(null, Array(this.options.inputCount));

    this.$inputs = $();

    $.each(size, function () {
      this.$inputs = this.$inputs.add($('<input />', {
        'class': classNames.input,
        maxlength: 1,
        size: 1,
        type: 'text'
      }));
    }.bind(this));

    this.$container .append(this.$inputs);
    this.$el.replaceWith(this.$container);
    this.$container.append(this.$el);

    text = this.filterString(inputValue);

    if (text.length) {
      inputIndex = this.setFromString(0, text);
    }

    if (inputAutofocus) {
      if (inputIndex === undefined) {
        focusIndex = 0;
      } else {
        focusIndex = (inputIndex == this.$inputs.length ? inputIndex - 1 : inputIndex);
      }
      this.$inputs.eq(focusIndex).focus();
    }
  };

  Multibox.prototype.handleKeydown = function handleKeydown(event) {
    var $input = $(event.target);
    var $prev;

    if (event.keyCode === 8) {
      event.preventDefault();

      $prev = $input.prev();

      if ($prev.length) {
        $prev.focus();
      }

      if (event.target.value) {
        $input.val('');
      } else {
        $prev.val('');
      }
    }

    this.update();
  };

  Multibox.prototype.handleInput = function handleInput(event) {
    var $input = $(event.target);
    var $next = $input.next();
    var value = $input.val();
    var filtered = this.filterString(value);

    $input.val(filtered);

    if (filtered && $next.length) {
      $next.focus();
    }

    this.update();
  };

  Multibox.prototype.handlePaste = function handlePaste(event) {
    event.preventDefault();

    var $input = $(event.target);
    var clipboardData = event.originalEvent.clipboardData;
    var text = clipboardData.getData('text');

    var filtered = this.filterString(text);

    if (!filtered.length) return;

    var inputIndex = this.setFromString(this.$inputs.index($input), filtered);
    var focusIndex = (inputIndex == this.$inputs.length ? inputIndex - 1 : inputIndex);

    this.$inputs.eq(focusIndex).focus();

    this.update();
  };

  Multibox.prototype.listen = function listen() {
    this.$inputs.on('input', this.handleInput.bind(this));
    this.$inputs.on('keydown', this.handleKeydown.bind(this));
    this.$inputs.on('paste', this.handlePaste.bind(this));
  };

  Multibox.prototype.filterString = function filterString(str) {
    return str.replace(this.options.regex, '');
  };

  Multibox.prototype.setFromString = function setFromString(index, str) {
    var inputIndex = index;
    var strIndex = 0;

    while (this.$inputs.eq(inputIndex).length && str[strIndex]) {
      this.$inputs.eq(inputIndex).val(str[strIndex]);
      inputIndex++;
      strIndex++;
    }

    return inputIndex;
  };

  Multibox.prototype.update = function update() {
    var values = [];
    var value;

    this.$inputs.each(function(i, input) {
      values.push(input.value);
    });

    value = values.join('');

    this.$el
      .val(value)
      .trigger('change');
  };

  $.fn.multibox = function multibox(options) {
    var instance;

    if (typeof options === 'object' || options == undefined) {
      options = (options || {});

      options = $.extend({}, {
        classNames: {
          container: 'multibox',
          input: 'multibox-input'
        },
        inputCount: 4,
        regex: /\D/g
      }, options);

      if (this.length) {
        instance = new Multibox(this, options);
        this.data('multibox', instance);
      }
    } else if (options === 'destroy') {
      if (this.data('multibox')) {
        instance = this.data('multibox');
        instance.destroy();
        this.data('multibox', null);
      }
    }
  };

}(jQuery));
