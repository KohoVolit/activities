<th>
<a href="../person/?id={$row->person_id}">
    {$row->family_name} {$row->given_name}</a>
    {* {if ($row['meta']['weight'] < 1)}
        <span title="{$t['not_whole_term']}"><sup>½</sup></span>
    {/if} *}
    <br/><small>{$row->political_group_name}</small>
    <br/><small>{$row->region_name}</small>
