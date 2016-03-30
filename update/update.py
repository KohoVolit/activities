import os

def include(filename):
    if os.path.exists(filename):
        exec(open(filename).read())

include('organizations.py')
print("organizations DONE")

include('people.py')
print("people DONE")

include('memberships.py')
print("memberships DONE")

include('activity_oral_interpellations.py')
print("activity_oral_interpellattions DONE")

include('activity_written_interpellations.py')
print("activity_written_interpellattions DONE")

include('activity_bill_proposals.py')
print("activity_bill_proposals DONE")

include("recalculate")
include('clean_webcache.py')
print('update DONE')
