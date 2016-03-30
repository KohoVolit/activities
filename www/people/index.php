<?php

$settings = json_decode(file_get_contents("../settings.json"));

require '../vendor/autoload.php';

$page = 'people';

$acts = [
    'bill proposal as first author',
    'bill proposal',
    'oral interpellation',
    'written interpellation'
];

require_once("../classes/people.php");

//set up Smarty
//require($settings->smarty_path);
$smarty = new Smarty();
$smarty->setTemplateDir($settings->app_path . 'smarty/templates');
$smarty->setCompileDir($settings->app_path . 'smarty/templates_c');

//get language
$lang = lang("../");

//include texts
    //page specific
$handle = fopen('../texts_' . $lang . '.csv', "r");
$texts = csv2array($handle);

// filter
$params = [];
$get = [];
if (isset($_GET['gid'])) {
    if (!is_array($_GET['gid']))
        $get['gid'] = [$_GET['gid']];
    else
        $get['gid'] = $_GET['gid'];
    $params['political_group_id'] = 'in.' . implode(',',$get['gid']);
}
if (isset($_GET['rid'])) {
    if (!is_array($_GET['rid']))
        $get['rid'] = [$_GET['rid']];
    else
        $get['rid'] = $_GET['rid'];
    $params['region_id'] = 'in.' . implode(',',$get['rid']);
}

$people = new people();

$regions = $people->getRegions();
$political_groups = $people->getPoliticalGroups();

foreach($regions as $r) {
    $ps = $get;
    $ps['rid'] = [$r->id];
    $r->filter_link = http_build_query($ps);
}
foreach($political_groups as $g) {
    $ps = $get;
    $ps['gid'] = [$g->id];
    $g->filter_link = http_build_query($ps);
}

$ids = $people->getIds($params);
$current_info = $people->getCurrentInfo($ids);
$activities = $people->getNumberOfActivities($ids);
$traffic_lights = $people->getTrafficLights($ids);

$smarty->assign('lang',$lang);
$smarty->assign('t',$texts);

$smarty->assign('settings',$settings);
$smarty->assign('page',$page);
$smarty->assign('acts',$acts);
$smarty->assign('political_groups',$political_groups);
$smarty->assign('regions',$regions);
$smarty->assign('current_info',$current_info);
$smarty->assign('activities',$activities);
$smarty->assign('traffic_lights',$traffic_lights);
//$smarty->assign('medians',$medians);
$smarty->display('people.tpl');

/**
* set language
*/
function lang($path2root) {
    if (isset($_GET['lang']) and (is_readable($path2root . 'texts_' . $_GET['lang'] . '.csv')))
        {
            $_SESSION["lang"] = $_GET['lang'];
            return $_GET['lang'];
        }
    else
        {
        if (isset($_SESSION['lang']))
            return $_SESSION['lang'];
        else //default language
            return 'cs';
        }
}
/**
* reads csv file into associative array
*
*/
function csv2array($handle, $pre = "") {
    $array = $fields = [];
    if ($handle) {
        while (($row = fgetcsv($handle, 4096)) !== false) {
            if (empty($fields)) {
                $fields = $row;
                continue;
            }
            $array[$row[0]] = (isset($row[1]) ? $row[1] : "");
        }
        if (!feof($handle)) {
            /*echo "Error: unexpected fgets() fail\n";*/
        }
    }
    return $array;
}
?>
