Postal.Helpers =
  numberWithDelimiters: (number)->
    number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")

  pluralize: (number, word)->
    if number == 1
      "1 #{word}"
    else
      "#{number} #{word}s"

  numberToHumanSize: (sizeInBytes)->
    wholes = Math.floor(Math.log(sizeInBytes) / Math.log(1024))
    unit = ['bytes', 'KB', 'MB', 'GB', 'TB'][wholes]
    i = (sizeInBytes / Math.pow(1024, wholes))
    if unit
      i = if unit == 'bytes' then i.toFixed(0) else i.toFixed(2)
      "#{i} #{unit}"
    else
      "0 bytes"

  styleWidth: (width)->
    width = 100 if width > 100.0
    width = 0 if width < 0
    string = "width:#{width}%;"
    if width >= 100
      string = string + "background-color:#e2383a;"
    else if width >= 90
      string = string + "background-color:#e8581f;"
    string
