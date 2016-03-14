# insert and update organizations
# chamber and political groups

import json

import api
import scrapeutils

url = 'http://www.psp.cz/eknih/cdrom/opendata/poslanci.zip'
unlfile = 'organy.unl'

api.login(authentication.email,authentication.password)

zfile = scrapeutils.download(url,zipped=True)
organy = scrapeutils.zipfile2rows(zfile,unlfile)
# chamber:
for row in organy:
    if row[2] == '11':  #chamber
        term = row[3][3:]
        org = {
            "name": row[4].strip(),
            'classification': 'chamber',
            'id': int(row[0].strip()),
            'founding_date': scrapeutils.cs2iso(row[6].strip()),
            'attributes': {
                "abbreviation": "PSP",
                "term": int(term)
            }
        }
        if (row[7].strip() != ''):
            org["dissolution_date"] = scrapeutils.cs2iso(row[7].strip())

        params = {'id': "eq.%s" % (org['id'])}
        r = api.get("organizations", params)
        rdata = r.json()
        if len(rdata) == 0:
            r = api.post("organizations",org)
        else:
            o = r.json()[0]
            try:
                z = o['attributes'].copy()
                z.update(org['attributes'])
                org['attributes'] = z
            except:
                nothing = None
            r = api.patch("organizations", params, org)

# political groups:
for row in organy:
    if row[2] == '1':   #political group
        params = {
            "id": "eq."+row[1].strip()
        }
        parent = api.get_one("organizations",params)

        org = {
            "name": row[4].strip(),
            'classification': 'political group',
            'id': int(row[0].strip()),
            'founding_date': scrapeutils.cs2iso(row[6].strip()),
            'attributes': {
                "abbreviation": row[3].strip(),
                "parent_id": parent['id'],
                "term": parent['attributes']['term']
            }
        }
        if (row[7].strip() != ''):
            org["dissolution_date"] = scrapeutils.cs2iso(row[7].strip())

        params = {'id': "eq.%s" % (org['id'])}
        r = api.get("organizations", params)
        rdata = r.json()
        if len(rdata) == 0:
            r = api.post("organizations",org)
        else:
            o = r.json()[0]
            try:
                z = o['attributes'].copy()
                z.update(org['attributes'])
                org['attributes'] = z
            except:
                nothing = None
            r = api.patch("organizations", params, org)

# regions
for row in organy:
    if row[2] == '75' or row[2] == '8':   #regions
        params = {
            "id": "eq."+row[1].strip()
        }

        org = {
            "name": row[4].strip(),
            'classification': 'region',
            'id': int(row[0].strip()),
            'founding_date': scrapeutils.cs2iso(row[6].strip()),
            'attributes': {
                "abbreviation": row[3].strip()
            }
        }
        if row[2] == '8':   # old regions
            row[7] = '31.05.2002'
        if (row[7].strip() != ''):
            org["dissolution_date"] = scrapeutils.cs2iso(row[7].strip())

        params = {'id': "eq.%s" % (org['id'])}
        r = api.get("organizations", params)
        rdata = r.json()
        if len(rdata) == 0:
            r = api.post("organizations",org)
        else:
            o = r.json()[0]
            try:
                z = o['attributes'].copy()
                z.update(org['attributes'])
                org['attributes'] = z
            except:
                nothing = None
            r = api.patch("organizations", params, org)

# electoral lists
for row in organy:
    if row[2] == '6':   # electoral list
        params = {
            "id": "eq."+row[1].strip()
        }

        org = {
            "name": row[4].strip(),
            'classification': 'electoral list',
            'id': int(row[0].strip()),
            'founding_date': scrapeutils.cs2iso(row[6].strip()),
            'attributes': {
                "abbreviation": row[3].strip()
            }
        }
        if (row[7].strip() != ''):
            org["dissolution_date"] = scrapeutils.cs2iso(row[7].strip())

        params = {'id': "eq.%s" % (org['id'])}
        r = api.get("organizations", params)
        rdata = r.json()
        if len(rdata) == 0:
            r = api.post("organizations",org)
        else:
            o = r.json()[0]
            try:
                z = o['attributes'].copy()
                z.update(org['attributes'])
                org['attributes'] = z
            except:
                nothing = None
            r = api.patch("organizations", params, org)
