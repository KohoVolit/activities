<?php
/**
* functions for one person
* current values (i.e., for current mps)
*/

//get api
require 'api.php';

class person {

    function __construct() {
        $this->api = new api();
    }

    // get basic info about a person
    public function getInfo($id) {
        $res = $this->api->get_one('people',["id"=>"eq.".$id]);
        $res->photo = $this->getLastPhoto($res);
        return $res;
    }

    public function getActivities($id) {
        $activities = [];
        //oral interpellations
        $activities['oral_interpelations'] = $this->api->get_all('current_activities_of_current_people', ["person_id" => 'eq.' . $id, "activity_classification" => "eq." . "oral interpellation", "order" => "activity_start_date.desc"]);
        $activities['written_interpelations'] = $this->api->get_all('current_activities_of_current_people', ["person_id" => 'eq.' . $id, "activity_classification" => "eq." . "written interpellation", "order" => "activity_start_date.desc"]);
        $activities['bill_proposals'] = $this->api->get_all('current_activities_of_current_people', ["person_id" => 'eq.' . $id, "activity_classification" => "eq." . "bill proposal", "order" => "activity_start_date.desc"]);
        $activities['bill_proposals_as_first_author'] =
        $this->api->get_all('current_bill_proposals_as_first_author_of_current_people', ["person_id" => 'eq.' . $id, "order" => "activity_start_date.desc"]);
        return $activities;
    }

    // return last photo of person
    function getLastPhoto($person_info) {
        if (isset($person_info->attributes->identifiers) and count($person_info->attributes->identifiers) > 0) {
            $max = 0;
            foreach ($person_info->attributes->identifiers as $identifier) {
                $parts = explode("/",$identifier->scheme);
                if ((count($parts) >= 3) and ($parts[0] == 'psp.cz') and ($parts[1] == 'poslanec') and ((int) $parts[2] > $max))
                    $max = (int) $parts[2];
            }
            $terms = $this->getStartYearOfTerms();

            $out = "http://www.psp.cz/eknih/cdrom/"
                . $terms[$max]
                . "ps/eknih/"
                . $terms[$max]
                . "ps/poslanci/i"
                . $person_info->id
                . ".jpg";
            return $out;
        }
        return '';
    }

    // return array of term id => year (for photos)
    function getStartYearOfTerms() {
        $arr = [];
        $res = $this->api->get_all("organizations",["classification" => "eq.chamber"]);
        foreach ($res as $row) {
            $parts = explode("-",$row->founding_date);
            $arr[$row->attributes->term] = $parts[0];
        }
        return $arr;
    }

}

$person = new person();
$p = $person->getActivities(237);

print_r($p);

?>
