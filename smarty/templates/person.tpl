{extends file='main.tpl'}
{block name=additionalHead}
<script src="//cdn.bootcss.com/d3/3.5.6/d3.min.js"></script>
<script src="{$settings->app_url}libs/modernizr.svg.js"></script>
<script src="{$settings->app_url}libs/d3.timelineplot.js"></script>
{/block}
{block name=body}
    <!-- top -->
    {include "person_top.tpl"}
    <!-- /top -->

    <!-- activities -->
    {include "person_activities.tpl"}
    <!-- /activities -->

    <div class="alert alert-info" role="alert">
      {$t['data_info']}<br>
      {* {$t['last_updated']}: {$last_updated} *}
    </div>

{/block}
