<?php

$settings = json_decode(file_get_contents("../settings.json"));

$page = 'person';

$acts = [
    'bill proposal as first author',
    'bill proposal',
    'oral interpellation',
    'written interpellation'
];

require_once("../classes/person.php");

//get language
$lang = lang("../");

//include texts
    //page specific
$handle = fopen('../texts_' . $lang . '.csv', "r");
$texts = csv2array($handle);

if (isset($_GET['id']))
    $id = $_GET['id'];
else {
    //redirect
}

//set up Smarty
require($settings->smarty_path);
$smarty = new Smarty();
$smarty->setTemplateDir($settings->app_path . 'smarty/templates');
$smarty->setCompileDir($settings->app_path . 'smarty/templates_c');

$person = new person();

//info
$info = $person->getInfo($id);
$current_info = $person->getCurrentInfo($id);
//activities
$activities = $person->getActivities($id);

// print_r($activities['bill proposal as first author']);
// print_r($activities['written interpellation']);
// die();

//traffic lights
$traffic_lights_arr = $person->getTrafficLights($id);
$traffic_lights = [];
foreach ($traffic_lights_arr as $tl)
    $traffic_lights[$tl->activity_classification] = $tl;
//medians
$medians_arr = $person->getMedians();
$medians = [];
foreach ($medians_arr as $m)
    $medians[$m->activity_classification] = $m;

$smarty->assign('lang',$lang);
$smarty->assign('t',$texts);

$smarty->assign('settings',$settings);
$smarty->assign('page',$page);
$smarty->assign('acts',$acts);
$smarty->assign('info',$info);
$smarty->assign('current_info',$current_info);
$smarty->assign('activities',$activities);
$smarty->assign('traffic_lights',$traffic_lights);
$smarty->assign('medians',$medians);
$smarty->display('person.tpl');


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
