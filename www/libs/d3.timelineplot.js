/* requires D3 + https://github.com/Caged/d3-tip */
d3.timelineplot = function() {
    //defaults
    ticksnumber = 3;
    pointcolor = "red";
    mobile_threshold = 500;
    function timelineplot(selection) {
        selection.each(function(d, i) {
            //options
            var data = (typeof(data) === "function" ? data(d) : d.data),
                margin = (typeof(margin) === "function" ? margin(d) : d.margin),
                minmaxdate = (typeof(minmaxdate) === "function" ? minmaxdate(d) : d.minmaxdate),
                ticksnumber_val = (typeof(ticksnumber) === "function" ? ticksnumber(d) : (typeof(d.ticksnumber) === "undefined" ? ticksnumber : d.ticksnumber)),
                pointcolor_val = (typeof(pointcolor) === "function" ? pointcolor(d) : (typeof(d.pointcolor) === "undefined" ? pointcolor : d.pointcolor)),
                size = (typeof(size) === "function" ? size(d) : d.size)
                ;

            // chart sizes
            var width = size['width'] - margin.left - margin.right,
                height = size['height'] - margin.top - margin.bottom;

            // define the x scale (horizontal)
            var mindate = minmaxdate['min'],
                maxdate = minmaxdate['max'];

            //set up scales
            var xScale = d3.time.scale()
			             .domain([mindate, maxdate])
			             .range([0, width]);
			var yScale = d3.scale.linear()
			             .domain([0, 1])
			             .range([height, 0]);

			 //set up axis
			 var xAxis = d3.svg.axis().scale(xScale);

			 // define element
			 var element = d3.select(this);

//			 var svg = element.append("svg")
//                .attr("width", width + margin.left + margin.right)
//                .attr("height", height + margin.top + margin.bottom)
//              .append("g")
//                .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
			  // 2 x axes
			  element.append("g")
                  .attr("class", "x-axis axis timeline-axis")
                  .attr("transform", "translate(0," + height + ")")
                  .call(xAxis
                    //.orient("bottom")
                    .ticks(ticksnumber_val)
                    //.tickValues([new Date(2013,0,1)])
                  );
              element.append("g")
                  .attr("class", "x axis timeline-axis")
                  //.attr("transform", "translate(0," + height + ")")
                  .call(xAxis
                    .ticks(0)
                    .tickValues([])
                  );

              //create points
              element.selectAll(".rectangle")
                    .data(data)
                        .enter()
                    .append("rect")
                        .attr("x", function(d,i) {
                            return xScale(Date.parse(d.activity_start_date));
                        })
                        .attr("y", function(d,i) {
                            return yScale(1);
                        })
                        .attr("width", 1)
                        .attr("height",function() {
                            return yScale(0) - yScale(1);
                        })
                        .attr("fill", pointcolor_val)
                        .attr("fill-opacity", 1)
                        .attr("class","timeline-rect")
                        .attr("title",function(d) {
                            var dat = new Date(d.activity_start_date);
                            return dat.toDateString() + ": " + d.activity_name;
                        });

        });
    }
    //
    timelineplot.data = function(value) {
        if (!arguments.length) return value;
            data = value;
        return timelineplot;
    }
    timelineplot.minmaxdate = function(value) {
        if (!arguments.length) return value;
            minmaxdate = value;
        return timelineplot;
    }
    timelineplot.ticksnumber = function(value) {
        if (!arguments.length) return value;
            ticksnumber = value;
        return timelineplot;
    }
    timelineplot.pointcolor = function(value) {
        if (!arguments.length) return value;
            pointcolor = value;
        return timelineplot;
    }
    timelineplot.margin = function(value) {
        if (!arguments.length) return value;
            margin = value;
        return timelineplot;
    }
    timelineplot.size = function(value) {
        if (!arguments.length) return value;
            size = value;
        return timelineplot;
    }
    return timelineplot;
}
