<h3>
    <i class="fa fa-circle traffic-color-{$traffic_lights[$act]->traffic_light} fa-2x"></i>
{*{$t[{$activity}]}*}
{$act}
<small>
{$t['count']}
    {count($activities[$act])}

, {$t['median']} {$medians[$act]->count}
</small>
</h3>
<div id="chart-{str_replace(' ','-',$act)}" data-activity="{str_replace(' ','-',$act)}" class="chart-activity"></div>
