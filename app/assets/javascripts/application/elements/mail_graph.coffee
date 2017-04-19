$(document).on 'turbolinks:load', ->

  mailGraph = $('.mailGraph')

  if mailGraph.length
    data = JSON.parse(mailGraph.attr('data-data'))
    incomingMail = []
    outgoingMail = []
    for d in data
      incomingMail.push(d.incoming)
      outgoingMail.push(d.outgoing)

    data =
      series: [outgoingMail, incomingMail]
    options =
      fullWidth: true
      axisY:
        offset:40
      axisX:
        showGrid: false
        offset: 0
        showLabel: true
      height: '230px'
      showArea: true
      high: if incomingMail? && incomingMail.length then undefined else 1000
      chartPadding:
        top:0
        right:0
        bottom:0
        left:0

    new Chartist.Line '.mailGraph__graph', data, options
