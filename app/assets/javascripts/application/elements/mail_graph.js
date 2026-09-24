function renderMailGraph() {
  const graph = document.querySelector(".mailGraph");
  if (!graph) {
    return;
  }
  const data = JSON.parse(graph.getAttribute("data-data"));
  const incomingMail = data.map((d) => d.incoming);
  const outgoingMail = data.map((d) => d.outgoing);

  new Chartist.Line(
    ".mailGraph__graph",
    { series: [outgoingMail, incomingMail] },
    {
      fullWidth: true,
      axisY: { offset: 40 },
      axisX: { showGrid: false, offset: 0, showLabel: true },
      height: "230px",
      showArea: true,
      high: incomingMail?.length ? undefined : 1000,
      chartPadding: { top: 0, right: 0, bottom: 0, left: 0 },
    }
  );
}

document.addEventListener("DOMContentLoaded", renderMailGraph);
document.addEventListener("turbo:load", renderMailGraph);
