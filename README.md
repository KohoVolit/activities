# Parliamentary activities in CZ
cz.parldata.net

## Settings
### /update
authentication.py
settings.py
webcache/
### /www
settings.json

## API
API is using Postgrest, see http://postgrest.com/api/reading/ for detailed description of usage and available operators.

The API request must be in following format:

    http://api.cz.parldata.net/resource?optional_parameters

### Resources
#### people

    /people

Get MP with id `4` (ids are kept from psp.cz):

    /people?id=eq.4

Get MP with last name `Benda`:

    /people?last_name=Benda

#### organizations

    /organizations

Get current chamber:

    /organizations?classification=eq.chamber&dissolution_date=is.null

#### current_people
Get list of current MPs:

    /current_people

#### current_political_groups
Get list of current political groups in psp

    /current_political_groups

#### current_activities_of_current_people
Get list of activities by current MPs (in current parliamentary term)

    /current_activities_of_current_people

Get list of activities by a single MP

    /current_activities_of_current_people?person_id=eq.4

#### current_bill_proposals_as_first_author_of_current_people
Get list of special activity "bill proposal as the first author" by current MPs (in current parliamentary term)

    /current_bill_proposals_as_first_author_of_current_people

#### current_people_traffic_lights
Get values of "traffic lights" for current MPs and number of their activities during the current parliamentary term (first third of MPs gets `green`, second third `yellow` and the last third `red`)

    /current_people_traffic_lights

Get the value of traffic lights for a single

#### current_people_stars
Similar to current_people_traffic_lights, but with number of stars in [1, 5].

    /current_people_stars
