# insert and update oral interpellations

from datetime import datetime
import json

import api
import scrapeutils

url = 'http://www.psp.cz/eknih/cdrom/opendata/interp.zip'
unlfile1 = 'li.unl'
unlfile2 = 'poradi.unl'
unlfile3 = 'p-stav.unl'
unlfile4 = 'uitypv.unl'

api.login(authentication.email,authentication.password)

zfile = scrapeutils.download(url,zipped=True)
li = scrapeutils.zipfile2rows(zfile,unlfile1)
poradi = scrapeutils.zipfile2rows(zfile,unlfile2)
pstav = scrapeutils.zipfile2rows(zfile,unlfile3)
uitypv = scrapeutils.zipfile2rows(zfile,unlfile4)

orgs = api.get_all("organizations")
org_ids = []
for org in orgs:
    org_ids.append(org['id'])

people = api.get_all("people")
people_ids = []
for person in people:
    people_ids.append(person['id'])

# for inserting poeple who are not MPs (ministers):
url = 'http://www.psp.cz/eknih/cdrom/opendata/poslanci.zip'
unlfile_osoby = 'osoby.unl'

zfile = scrapeutils.download(url,zipped=True)
osoby = scrapeutils.zipfile2rows(zfile,unlfile_osoby)

def insertperson(pid):
    for row in osoby:
        oid = row[0].strip()
        if oid == pid:
            person = person = {
                "id": int(oid),
                "family_name" : row[2].strip(),
                "given_name" : row[3].strip(),
                "attributes": {
                    "birth_date": scrapeutils.cs2iso(row[5].strip())
                }
            }
            if row[6].strip() == "M":
                person['attributes']['gender'] = 'male'
            else:
                person['attributes']['gender'] = 'female'
            if row[1].strip() != "":
                person['attributes']['honorific_prefix'] = row[1].strip()
            if row[4].strip() != "":
                person['attributes']['honorific_suffix'] = row[4].strip()
            if row[8].strip() != "":
                person['attributes']['death_date'] = scrapeutils.cs2iso(row[8].strip())
            api.post("people",person)

# reorder arrays for easier access:
uitypv_dict = {}
pstav_dict = {}
li_dict  = {}
for row in uitypv:
    uitypv_dict[row[0]] = row
for row in pstav:
    pstav_dict[row[0]] = row
for row in li:
    li_dict[row[0]] = row

# for each activity
for row in poradi:
    try:
        d = datetime.strptime(li_dict[row[1]][3].strip(), '%Y-%m-%d %H:%M:%S.%f').strftime('%Y-%m-%d %H:%M:%S')
    except:
        d = datetime.strptime(li_dict[row[1]][1].strip(), '%d.%m.%Y').strftime('%Y-%m-%d %H:%M:%S')
    activity = {
        "classification": "oral interpellation",
        "name": row[4].strip(),
        "start_date": d,
        "source_code": row[0]
    }
    #status
    activity['attributes'] = {}
    try:
        activity['attributes']['status'] = {
            "code": pstav_dict[row[0]][1],
            "text": uitypv_dict[pstav_dict[row[0]][1]][1].strip(),
            "hansard_source_code": uitypv_dict[pstav_dict[row[0]][1]][3].strip()
        }
    except:
        activity['attributes']['status'] = {"code": "unknown"}
    # identificators
    activity['attributes']['identificators'] = {
        "source_id": row[0]
    }
    # people
    activity['attributes']['people'] = {
        "from_person_id": int(row[2]),
        "to_person_id": int(row[3])
    }
    if li_dict[row[1]][2].strip() == 'P':
        activity['attributes']['people']['type'] = 'prime minister'
    else:
        activity['attributes']['people']['type'] = 'minister'
    # check people:
    if not int(row[2]) in people_ids:
        print("missing (from) person id " + row[2])
    if not int(row[3]) in people_ids:
        print("inserting missing (to) person id " + row[3])
        insertperson(row[3])
        people_ids.append(int(row[3]))
    # draw
    activity['attributes']['draw'] = {
        "id": int(row[1]),
        "start_date": d,
        "order": int(row[5]),
        "priority": row[6]
    }
    # session
    activity['attributes']['session'] = {
        "source_id": li_dict[row[1]][4],
        "topic_source_id": li_dict[row[1]][5],
        "number": li_dict[row[1]][6],
        "organization_id": int(li_dict[row[1]][7]),
    }

    # API
    params = {
        "classification":"eq.oral interpellation",
        "source_code":"eq."+row[0]
    }
    r = api.get_one("activities",params)
    if r:
        api.patch("activities",params,activity)
    else:
        r = api.post("activities",activity)
        activity_id = api.post_id(r)
        postdata = {
            "activity_id": activity_id,
            "person_id": int(row[2])
        }
        api.post("activityships",postdata)
