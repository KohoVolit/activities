<?php
/**
* Basic API client module
* read-only
*/


//get guzzle
require '../vendor/autoload.php';

class api {


    function __construct() {
        //guzzle
        $this->client = new GuzzleHttp\Client();

        //load settings
        $this->root = str_replace('classes/api.php','',__FILE__);
        $this->settings = json_decode(file_get_contents($this->root . "settings.json"));
        //headers
        $this->headers = ['Content-Type' => 'application/json'];
    }

    // GET
    // returns whole object
    public function get($resource, $params=NULL, $headers=NULL) {
        $res = $this->client->request('GET',
            $this->settings->api_url . $resource,
            [
                'query' => $params,
                'headers' => $headers,
                'http_errors' => false
            ]
        );
        return $res;
    }

    //GET single item
    //Returns NULL if no such item exists
    public function get_one($resource, $params=NULL) {
        $headers = $this->headers;
        $headers['Prefer'] = 'plurality=singular';
        $res = $this->client->request('GET',
            $this->settings->api_url . $resource,
            [
                'query' => $params,
                'headers' => $headers,
                'http_errors' => false
            ]
        );
        if ($res->getStatusCode() < 300) {
            return json_decode($res->getBody());
        } else {
            return NULL;
        }
    }

    // GET all items
    // Returns the array of the objects
    public function get_all($resource, $params=NULL) {

        $arr = [];
        $res = $this->get($resource,$params,$this->headers);
            if ($res->getStatusCode() < 300) {
                $parts = explode('/',$res->getHeader('Content-Range')[0]);
                $size = (int) $parts[1];
                $parts0 = explode('-',$parts[0]);
                if (isset($parts0[1])) {
                    $last = (int) $parts0[1];
                } else {
                    $last = 0;
                }
                $arr = json_decode($res->getBody());
                $headers = $this->headers;
                $i = 0;
                while (($last+1) < $size) {
                    $headers['Range'] = ($last + 1) . '-';
                    $r = $this->get($resource,$params,$headers);
                    $parts = explode('/',$r->getHeader('Content-Range')[0]);
                    $parts0 = explode('-',$parts[0]);
                    $last = $parts0[1];
                    $arr = array_merge($arr,json_decode($r->getBody()));
                }
                return $arr;
            } else {
                return $arr;
            }
    }

}
//
// $api = new api();
//
// $res = $api->get_all("current_bill_proposals_as_first_author_of_current_people",['person_id'=>'eq.6150']);
//
//
// print_r( $res);




?>
