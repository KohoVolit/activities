# insert and update written interpellations

from datetime import datetime
import json

import api
import authentication
import scrapeutils

url = 'http://www.psp.cz/eknih/cdrom/opendata/tisky.zip'
unlfile = 'tisky.unl'

api.login(authentication.email,authentication.password)

zfile = scrapeutils.download(url,zipped=True)
tisky = scrapeutils.zipfile2rows(zfile,unlfile)

# terms
chambers = api.get_all("organizations")
chambers_dict = {}
for chamber in chambers:
    chambers_dict[chamber['id']] = chamber

# for each activity
for row in tisky:
    if row[1].strip() == '6':
        if (row[8].strip() == "0") or (row[8].strip() == ""):
            print(row)
        else:
            activity = {
                "classification": "written interpellation",
                "name": row[10].strip(),
                "start_date": datetime.strptime(row[11], '%d.%m.%Y').strftime('%Y-%m-%d %H:%M:%S'),
                "source_code": row[0]
            }
            #attributes
            attrs = {
                "person_id": int(row[8]),
                "full_name": row[15].strip(),
                "organization_id": int(row[7]),
                "document": {
                    "id": int(row[3]),
                    "term":chambers_dict[int(row[7])]['attributes']['term']
                }
            }
            if row[19].strip() == "":
                attrs['url'] = "http://psp.cz/sqw/historie.sqw?o=%s&T=%s" % (str(chambers_dict[int(row[7])]['attributes']['term']), row[3])
            else:
                attrs['url'] = "http://psp.cz" + row[19].strip()
            activity['attributes'] = attrs

            # API
            params = {
                "classification":"eq.written interpellation",
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
                    "person_id": int(row[8])
                }
                api.post("activityships",postdata)
