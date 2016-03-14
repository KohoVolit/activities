# insert and update people (MPs)

import json

import api
import scrapeutils


url = 'http://www.psp.cz/eknih/cdrom/opendata/poslanci.zip'
unlfile_osoby = 'osoby.unl'
unlfile_poslanec = 'poslanec.unl'

zfile = scrapeutils.download(url,zipped=True)
osoby = scrapeutils.zipfile2rows(zfile,unlfile_osoby)
poslanec = scrapeutils.zipfile2rows(zfile,unlfile_poslanec)

api.login(authentication.email,authentication.password)

oosoby = {}
for row in osoby:
  oosoby[row[0].strip()] = row

persons = {}
terms = {}
address = {
    6: 'street',
    7: 'municipality',
    8: 'postcode'
}
attrs = {
    5: 'link',
    9: 'email',
    10: 'phone',
    13: 'facebook'
}
for row in poslanec:
    oid = row[1].strip()
    if oid == '6138':
        raise(Exception)
    try:
        terms[row[4].strip()]
    except:
        r = api.get_one("organizations",{"id":"eq." + row[4].strip()})
        terms[row[4].strip()] = r['attributes']['term']
    try:
        persons[oid]
    except:
        person = {
            "id": int(oid),
            "family_name" : oosoby[oid][2].strip(),
            "given_name" : oosoby[oid][3].strip(),
            "attributes": {
                "birth_date": scrapeutils.cs2iso(oosoby[oid][5].strip()),
                "identifiers": [{
                    "scheme": "psp.cz/poslanec/"+str(terms[row[4].strip()]),
                    "identifier": row[0].strip()
                }]
            }
        }
        if oosoby[oid][6].strip() == "M":
            person['attributes']['gender'] = 'male'
        else:
            person['attributes']['gender'] = 'female'
        if oosoby[oid][1].strip() != "":
            person['attributes']['honorific_prefix'] = oosoby[oid][1].strip()
        if oosoby[oid][4].strip() != "":
            person['attributes']['honorific_suffix'] = oosoby[oid][4].strip()
        if oosoby[oid][8].strip() != "":
            person['attributes']['death_date'] = scrapeutils.cs2iso(oosoby[oid][8].strip())
        persons[oid] = person
    else:
        persons[oid]['attributes']["identifiers"].append(
            {"identifier": row[0].strip(), "scheme": "psp.cz/poslanec/"+str(terms[row[4].strip()])}
        )

    for k in attrs:
        if not (row[k].strip() == "" or row[k].strip() == "\\"):
            persons[oid]['attributes'][attrs[k]] = row[k].strip()

    for k in range(6,9):
        if not (row[k].strip() == "" or row[k].strip() == "\\"):
            try:
                persons[oid]['attributes']['address']
            except:
                persons[oid]['attributes']['address'] = {}
            persons[oid]['attributes']['address'][address[k]] = row[k].strip()
