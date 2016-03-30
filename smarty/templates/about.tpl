{extends file='main.tpl'}
{block name=body}

    <div class="container" style="max-width:666px">
        <h1>{$t['about']}</h1>
        <ul>
            <li><a href="#about">{$t['about']}</a>
            {* <li><a href="#methodology">{$t['methodology']}</a>
            <li><a href="#studies">{$t['more_studies']}</a> *}
        </ul>

        <a name="about"><h3>{$t['about']}</h3></a>
        {$about_text}
        {* <a name="methodology"><h3>{$t['methodology']}</h3></a>
        {$methodology_text}
        <a name="studies"><h3>{$t['more_studies']}</h3></a>
        {$studies_text} *}
    </div>

{/block}
