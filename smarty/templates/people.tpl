{extends file='main.tpl'}
{block name=additionalHead}
<script src="{$settings->app_url}libs/jquery.stickytableheaders.min.js"></script>
<script src="{$settings->app_url}libs/sorttable.js"></script>
{/block}
{block name=body}

    <script>
        //shows and hides
        $(function() {
            $(".show-details").click(function(){
                $("#"+this.id+"-body").show(100);
                $("#"+this.id).hide();
            });
        })
        $(function () {
            $("#explore-table").stickyTableHeaders();
            $('[data-toggle="tooltip"]').tooltip();
        });
    </script>

    <h1 class="text-center">{$t['title']}</h1>

    <!-- filter -->
    <div class="alert alert-warning">
      <div class="row">
        <div class="col-sm-1">
          <h4><i class="fa fa-filter"></i> {$t['filter']}</h4>
        </div>
        <div class="col-sm-11">
            <p>
            {$t['groups']}:
            {foreach $political_groups as $group}
                <span class="label label-primary"><a href="?{$group->filter_link}">{$group->attributes->abbreviation}</a></span>
            {/foreach}
            <span class="label label-primary"><a href="./">{$t['all']}</a></span>
            <p>
            {$t['countries']}:
            {foreach $regions as $region}
                <span class="label label-primary"><a href="?{$region->filter_link}"> {$region->name}</a></span>
            {/foreach}
            <span class="label label-primary"><a href="./">{$t['all']}</a></span>
        </div>
      </div>
    </div>
    <!-- /filter -->

    <!-- info -->
    <div class="alert alert-info">
        <div class="row">
            <div class="col-sm-1">
                <h4><i class="fa fa-info-circle"></i><br>{$t['info']}</h4>
            </div>
            <div class="col-sm-11">
                <p>{$t['info_explanation_people']}
            </div>
        </div>
    </div>
    <!-- /info -->

    {include "people_table.tpl"}

    <div class="alert alert-info" role="alert">
      {$t['data_info']}<br>
      {* {$t['last_updated']}: {$last_updated} *}
    </div>
{/block}
