<?php

$settings = json_decode(file_get_contents("../settings.json"));

require '../vendor/autoload.php';

//get language
$lang = lang("../");

//include texts
    //page specific
$handle = fopen('../texts_' . $lang . '.csv', "r");
$texts = csv2array($handle);

//set up Smarty
//require($settings->smarty_path);
$smarty = new Smarty();
$smarty->setTemplateDir($settings->app_path . 'smarty/templates');
$smarty->setCompileDir($settings->app_path . 'smarty/templates_c');

$smarty->assign('about_text',file_get_contents("about.html"));
$smarty->assign('lang',$lang);
$smarty->assign('t',$texts);
$smarty->assign('settings',$settings);
$smarty->display('about.tpl');

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
