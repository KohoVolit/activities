# insert and update memberships

from datetime import datetime
import json
import time

import api
import authentication
import scrapeutils

url = 'http://www.psp.cz/eknih/cdrom/opendata/poslanci.zip'
unlfile = 'zarazeni.unl'

api.login(authentication.email,authentication.password)

zfile = scrapeutils.download(url,zipped=True)
zarazeni = scrapeutils.zipfile2rows(zfile,unlfile)

orgs = api.get_all("organizations")
org_ids = []
for org in orgs:
    org_ids.append(org['id'])

people = api.get_all("people")
people_ids = []
for person in people:
    people_ids.append(person['id'])

# for row in zarazeni:
#     if (int(row[0]) in people_ids) and (int(row[1]) in org_ids) and (int(row[2]) == 0):
#         membership = {
#             "person_id": int(row[0]),
#             "organization_id": int(row[1]),
#             "start_date": datetime.strptime(row[3].strip(), '%Y-%m-%d %H').strftime('%Y-%m-%d %H:%M:%S')
#         }
#         if row[4].strip() != "":
#             membership["end_date"] = datetime.strptime(row[4].strip(), '%Y-%m-%d %H').strftime('%Y-%m-%d %H:%M:%S')
#
#         params = {"person_id":"eq."+row[0], "organization_id": "eq." + row[1], "start_date": "eq." + membership['start_date']}
#         r = api.get_one("memberships",params=params)
#         if not r:
#             api.post("memberships",membership)
#         else:
#             api.patch("memberships",params=params,data=membership)


# regions and electoral lists
# note: they are in a differerent table
unlfile = 'poslanec.unl'
poslanec = scrapeutils.zipfile2rows(zfile,unlfile)

for row in poslanec:
    # regions
    i = 0
    ok = False
    while (not ((i>=10) or ok)):
        memb = api.get_one("memberships",
            params={"person_id": "eq."+row[1],"organization_id": "eq."+row[4]}
        )
        if len(memb) > 0:
            ok = True
        else:
            time.sleep(0.5)
        i += 1
    membership = {
        "person_id": int(row[1]),
        "organization_id": int(row[2]),
        "start_date": memb['start_date'],
        "end_date": memb['end_date']
    }
    params = {"person_id":"eq."+row[1], "organization_id": "eq." + row[2], "start_date": "eq." + membership['start_date']}
    r = api.get_one("memberships",params=params)
    if not r:
        api.post("memberships",membership)
    else:
        api.patch("memberships",params=params,data=membership)

    # electoral lists
    # note: some are missing
    if not (int(row[3]) == 0):
        membership = {
            "person_id": int(row[1]),
            "organization_id": int(row[3]),
            "start_date": memb['start_date'],
            "end_date": memb['end_date']
        }
        params = {"person_id":"eq."+row[1], "organization_id": "eq." + row[3], "start_date": "eq." + membership['start_date']}
        r = api.get_one("memberships",params=params)
        if not r:
            api.post("memberships",membership)
        else:
            api.patch("memberships",params=params,data=membership)
