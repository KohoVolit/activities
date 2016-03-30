<nav class="navbar navbar-inverse">
  <div class="container">
    <div class="navbar-header">

      <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar-collapse">
        <span class="sr-only">...</span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
      </button>
      <a class="navbar-brand{if $page=='front_page'} active{/if}" href="../">{$t['brand']}</a>
    </div>

    <div class="collapse navbar-collapse" id="navbar-collapse">
      <ul class="nav navbar-nav">
        <li {if $page=='people'}class='active'{/if}><a href="../people">{$t['mps']}</a></li>
        <li ><a href="https://github.com/KohoVolit/activities#api" target="_blank">API</a></li>
      </ul>

      <ul class="nav navbar-nav navbar-right">
        <li {if $page=='about'}class='active'{/if}><a href="{$settings->app_url}about">{$t['about']}</a></li>
      </ul>
    </div>
  </div>
</nav>
