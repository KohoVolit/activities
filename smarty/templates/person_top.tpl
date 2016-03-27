<div class="row" id="mep-top">
  <div class="col-sm-1"></div>
  <div class="col-sm-3">
    <div class="pull-right">
      <img width="113" height="143" src="{$info->photo}" class="img-circle" />
    </div>
  </div>
  <div class="col-sm-8">
    <ul>
      <li><h1><strong>{$info->given_name} {$info->family_name|@upper}</strong></h1></li>
      <li><strong>{$current_info->political_group_name}</strong>
      <li><strong>{$current_info->region_name}</strong>
      {* <li><img src="{$data['meta']['country_picture']}" alt="{$data['meta']['country_name']}" title="{$data['meta']['country_name']}" /> <strong>{$data['meta']['country_name']}</strong>
      {if ($data['meta']['weight'] < 1)}
      <li><strong>{$t['not_whole_term']}</strong>
    {/if} *}
    </ul>
  </div>
</div> <!-- /row -->
