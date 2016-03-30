<span class="center-block">
    <i class="fa fa-circle traffic-color-{$traffic_lights->$k->$act} fa-2x"></i>
    {if isset($activities->$k->$act)}
        {round($activities->$k->$act,1)|regex_replace:'/[.,]0+$/':''}
    {else}
        0
    {/if}
</span>
