# insert and update bill proposals

from datetime import datetime
import json
from operator import itemgetter

import api
import scrapeutils

url = 'http://www.psp.cz/eknih/cdrom/opendata/tisky.zip'
unlfile = 'tisky.unl'
unlfile2 = 'hist.unl'
unlfile3 = 'predkladatel.unl'

api.login(authentication.email,authentication.password)

zfile = scrapeutils.download(url,zipped=True)
tisky = scrapeutils.zipfile2rows(zfile,unlfile)
hist = scrapeutils.zipfile2rows(zfile,unlfile2)
predkladatel = scrapeutils.zipfile2rows(zfile,unlfile3)

# terms
chambers = api.get_all("organizations")
chambers_dict = {}
for chamber in chambers:
    chambers_dict[chamber['id']] = chamber

# history
hist_dict = {}
for row in hist:
    try:
        hist_dict[row[1]]
    except:
        hist_dict[row[1]] = []
    hist_dict[row[1]].append(row)

# people
predkladatel_dict = {}
for row in predkladatel:
    try:
        predkladatel_dict[row[0]]
    except:
        predkladatel_dict[row[0]] = []
    if not row[2] == '0':
        predkladatel_dict[row[0]].append({"person_id": int(row[1]), "rank": int(row[2])})

for k in predkladatel_dict:
    predkladatel_dict[k] = sorted(predkladatel_dict[k], key=itemgetter('rank'))

# for each activity
for row in tisky:
    if (row[1].strip() == '2') or (row[1].strip() == '1'):
        try:
            d = datetime.strptime(row[11], '%d.%m.%Y').strftime('%Y-%m-%d %H:%M:%S')
        except:
            d = None
        if d:
            activity = {
                "classification": "bill proposal",
                "name": row[10].strip(),
                "start_date": datetime.strptime(row[11], '%d.%m.%Y').strftime('%Y-%m-%d %H:%M:%S'),
                "source_code": row[0]
            }
            #attributes
            attrs = {
                "full_name": row[15].strip(),
                "organization_id": int(row[7]),
                "document": {
                    "id": int(row[3]),
                    "term":chambers_dict[int(row[7])]['attributes']['term']
                }
            }
            if row[18].strip() == "":
                attrs['url'] = "http://psp.cz/sqw/historie.sqw?o=%s&T=%s" % (str(chambers_dict[int(row[7])]['attributes']['term']), row[3])
            else:
                attrs['url'] = "http://psp.cz" + row[19].strip()

                #people
            attrs['people'] = {"person_ids": [], "count": 0}
            try:
                for r in predkladatel_dict[row[0]]:
                    if (r['person_id'] not in attrs['people']["person_ids"]) and (not r['person_id'] == 0):
                        attrs['people']["person_ids"].append(r['person_id'])
                attrs['people']['count'] = len(attrs['people']["person_ids"])
            except:
                nothing = None

                # law gazette
            attrs['law_gazette'] = {}
            try:
                for r in hist_dict[row[0]]:
                    if not r[11].strip() == "":
                        attrs['law_gazette']['date'] = datetime.strptime(r[11], '%d.%m.%Y').strftime('%Y-%m-%d %H:%M:%S')
                        attrs['law_gazette']['year'] = datetime.strptime(r[11], '%d.%m.%Y').strftime('%Y')
                        attrs['law_gazette']['volume'] = int(r[12])
                        attrs['law_gazette']['section'] = int(r[13])
            except:
                nothing = None

                #vote events
            attrs['vote_events'] = []
            try:
                for r in hist_dict[row[0]]:
                    if not r[3].strip() == '':
                        attrs['vote_events'].append(int(r[3]))
            except:
                nothing = None

            activity['attributes'] = attrs


            # API
            params = {
                "classification":"eq.bill proposal",
                "source_code":"eq."+row[0]
            }
            r = api.get_one("activities",params)
            if r:
                try:
                    api.patch("activities",params,activity)
                except:
                    print("cannot patch:",activity)
            else:
                r = api.post("activities",activity)
                activity_id = api.post_id(r)
                for person_id in attrs['people']['person_ids']:
                    postdata = {
                        "activity_id": int(activity_id),
                        "person_id": person_id
                    }
                    try:
                        api.post("activityships",postdata)
                    except:
                        print('activityship insert problem:', postdata)
        else:
            # print("no date:",row[0])
            nothing = None
