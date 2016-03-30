<?php
/**
* functions for MPs
* current values (i.e., for current mps)
*/

//get api
require 'api.php';

class people {

    function __construct() {
        $this->api = new api();
    }


    // ex.: $people->getIds(["political_group_id" => "eq.1106"]);
    public function getIds($params=Null) {
        $ids = [];
        $res = $this->api->get_all('current_people',$params);
        foreach ($res as $r) {
            $id = $r->person_id;
            $ids[] = $id;
        }
        return $ids;
    }

    // get current info about people (if current MPs)
    public function getCurrentInfo($ids=Null) {
        $res = $this->api->get_all('current_people',['person_id'=>'in.' . implode(',',$ids), 'order'=>'family_name.asc,given_name.asc']);
        //reorder
        $out = new stdClass();
        foreach ($res as $r) {
            $id = $r->person_id;
            $out->$id = $r;
        }
        return $out;
    }

    //get all activities in current term (if current MPs)
    public function getNumberOfActivities($ids=Null) {
        $out = new stdClass();
        $res = $this->api->get_all( 'number_of_all_current_activities_of_current_people', ['person_id'=>'in.' . implode(',',$ids)]);
        //reorder
        foreach ($res as $r) {
            $id = $r->person_id;
            $ac = $r->activity_classification;
            if (!isset($out->$id))
                $out->$id = new stdClass();
            $out->$id->$ac = $r->count;
        }
        return $out;
    }

    // get medians for all activities in current term (for current MPs)
    public function getMedians() {
        $medians = $this->api->get_all('activity_quantiles',["quantile" => "eq." . 0.5]);
        return $medians;
    }

    // get traffic lights for all activities in current term (if current MP)
    public function getTrafficLights($ids=Null) {
        $res = $this->api->get_all('current_people_traffic_lights',["person_id" => 'in.' . implode(',',$ids)]);
        //reorder
        $out = new stdClass();
        foreach ($res as $r) {
            $id = $r->person_id;
            $ac = $r->activity_classification;
            if (!isset($out->$id))
                $out->$id = new stdClass();
            $out->$id->$ac = $r->traffic_light;
        }
        return $out;
    }

    //get current political groups
    public function getPoliticalGroups() {
        $res = $this->api->get_all('current_political_groups',['order' => 'attributes->>abbreviation.asc']);
        //reorder
        $out = new stdClass();
        foreach ($res as $r) {
            $id = $r->id;
            $out->$id = $r;
        }
        return $out;
    }

    //get current regions
    public function getRegions() {
        $res = $this->api->get_all('organizations',['classification'=>'eq.region','dissolution_date' => 'is.NULL','order' => 'name.asc']);
        //reorder
        $out = new stdClass();
        foreach ($res as $r) {
            $id = $r->id;
            $out->$id = $r;
        }
        return $out;
    }


}

// $people = new people();
//
// // $info = $people->getCurrentInfo(["political_group_id" => "eq.1106"]);
// // $info = $people->getCurrentInfo();
//
// $ids = $people->getIds(["political_group_id" => "eq.1106"]);
// $activities = $people->getNumberOfActivities($ids);
// $traffic_lights = $people->getTrafficLights($ids);
//
// print_r($traffic_lights);

?>
