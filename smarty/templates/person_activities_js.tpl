<script>

String.prototype.replaceAll = function(search, replacement) {
    var target = this;
    return target.split(search).join(replacement);
};

var graphic_data = {json_encode($activities)};
var activities = {json_encode($acts)};
{literal}
var minmaxdate = { 'min':new Date(2013,9,1),'max':new Date() }

var $charts = $('.chart-activity');

var graphic_minmaxdate = minmaxdate;

var mobile_threshold = 500;


function drawGraphic() {

        // clear out existing graphics
    $charts.empty();



    /* Initialize tooltip */
/*       tip = d3.tip().attr('class', 'd3-tip').html(function(d) {
      return "<span class=\'stronger\'>" + d + "</span><br>";
    });*/

    /* Invoke the tip in the context of your visualization */
    /*svg.call(tip)*/


    var tlp = d3.timelineplot()
        .data(function(d) {return d.data})
        .margin(function(d) {return d.margin})
        .minmaxdate(function(d) {return d.minmaxdate})


    for (i = 0; i < activities.length; i++) {
        k = activities[i];
        $chart = $('#chart-'+k.replaceAll(' ','-'));
        if ($chart.width() < mobile_threshold)
            var margin = { top: 10, right: 5, bottom: 30, left: 40 };
        else
            var margin = { top: 10, right: 30, bottom: 30, left: 40 };
        var width = $chart.width() - margin.left;
        timelineplot = [{
            "data": function() {
                if (typeof(graphic_data[k]) === "undefined")
                    return [];
                else
                    return graphic_data[k]
            },
            "margin": margin,
            "minmaxdate": graphic_minmaxdate,
            "size":{"width":width,"height":75},
        }];

        var svg = d3.selectAll("#chart-"+k.replaceAll(' ','-'))
            .append("svg")
            .attr("width",timelineplot[0]['size']['width'])
            .attr("height",timelineplot[0]['size']['height']);


        var timeline = svg.selectAll("#chart-"+k.replaceAll(' ','-'))
            .data(timelineplot)
          .enter()
            .append("svg:g")

            .attr("transform", "translate(" + timelineplot[0].margin.left + "," + timelineplot[0].margin.top + ")")
            .call(tlp);
    }

}

if (Modernizr.svg) { // if svg is supported, draw dynamic chart
    drawGraphic();
    window.onresize = drawGraphic;

}
{/literal}
</script>
