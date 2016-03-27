/* requires D3 + https://github.com/Caged/d3-tip */
d3.rowplot = function() {
    //defaults
    colors = {"yes": "darkgreen" ,"no":"red"};
    tablet_threshold = 666;
    mobile_threshold = 500;
    function rowplot(selection) {
        selection.each(function(d, i) {
            //options
            var data = (typeof(data) === "function" ? data(d) : d.data),
                margin = (typeof(margin) === "function" ? margin(d) : d.margin),
                colors_val = (typeof(colors) === "function" ? colors(d) : (typeof(d.colors) === "undefined" ? colors : d.colors)),
                size = (typeof(size) === "function" ? size(d) : d.size),
                upper = (typeof(upper) === "function" ? upper(d) : d.upper),
                lower = (typeof(lower) === "function" ? lower(d) : d.lower)
                ;
            
            // chart sizes
            var width = size['width'] - margin.left - margin.right,
                height = size['height'] - margin.top - margin.bottom;
               
            //set up scales
            var xScale = d3.scale.linear()
			             .domain([0, 1])
			             .range([0, width])
			var yScale = d3.scale.linear()
			             .domain([0, 1])
			             .range([height, 0]);
			             
			 //set up axes
			 var xAxis = d3.svg.axis().scale(xScale);
			 
			 var xAxis2 = d3.svg.axis().scale(xScale)
			                .orient("top")               
			                ;
			 
			 // define element
			 var element = d3.select(this);

			  // 2 x axes
			 element.append("g")
                  .attr("class", "x-axis axis rowplot-axis") 
                  .attr("transform", "translate(0," + height + ")")
                  .call(xAxis
                    //.orient("bottom")
                    .ticks(0)
                   .tickValues([])
                  ); 
             element.append("g")
                  .attr("class", "x axis rowplot-axis") 
                  //.attr("transform", "translate(0," + height + ")")
                  .call(xAxis
                    .ticks(0)
                    .tickValues([])
                  );
              // more axes
//              if (size['width'] < mobile_threshold)
//			    nt = 3;
//			  else if (size['width'] < tablet_threshold)
//			    nt = 5;
//			  else nt = 10;

              if (size['width'] > tablet_threshold) {
                  element
                        .append("g")
                        .attr("class", "x-axis axis rowplot-axis")
                        .call(xAxis2
                            //.ticks(nt)
                            .tickValues(
                              upper.positions
                            )
                            .tickFormat(function(d,i){
                            return upper['labels'][i]
                            })
                            
                        )
                        .selectAll("text")
                            .attr("y", -5)
                            .attr("x", 0)
                            .style("text-anchor", "start");
              }

              var texts2 = element.selectAll(".text2")
		        .data(lower)
              .enter().append("text")
                //.attr('text-anchor',"middle")
//                .attr('font-family', 'sans-serif')
               .attr('font-size',function() { 
                if (size['width'] > mobile_threshold) {
                    return 13;
                } else {
                    return 8;
                }
               })
                .attr("transform", function(d) {return "rotate(25,"+xScale(d.position)+","+yScale(0)+")";})
                .attr('x',function(d) {return xScale(d.position);})
                .attr('y',function(d) {return yScale(-0.5)})
                .text(function(d) {return d.label});
                     
              
              //create points
              n = data.length;
              element.selectAll(".rectangle")
                    .data(data)
                        .enter()
                    .append("rect")
                        .attr("x", function(d,i) {
                            return xScale(i/n);
                        })
                        .attr("y", function(d,i) {
                            return yScale(1);
                        })
                        .attr("width", function() {
                            return xScale(1/n);
                        })
                        .attr("height",function() {
                            return yScale(0) - yScale(1);
                        })
                        .attr("fill", function(d) {
                            if (d == 1) return colors_val['yes'];
                            else return colors_val['no'];
                        })
                        .attr("fill-opacity", 1)
                        .attr("class","rowplot-rect");        
			             
        });
    }
    //
    rowplot.data = function(value) {
        if (!arguments.length) return value;
            data = value;
        return rowplot;
    }
    rowplot.colors = function(value) {
        if (!arguments.length) return value;
            colors = value;
        return rowplot;
    }
    rowplot.margin = function(value) {
        if (!arguments.length) return value;
            margin = value;
        return rowplot;
    }
    rowplot.size = function(value) {
        if (!arguments.length) return value;
            size = value;
        return rowplot;
    }
    rowplot.size = function(upper) {
        if (!arguments.length) return value;
            upper = value;
        return rowplot;
    }
    rowplot.size = function(lower) {
        if (!arguments.length) return value;
            lower = value;
        return rowplot;
    }
    return rowplot;
}
