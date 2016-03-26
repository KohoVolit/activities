import os

def include(filename):
    if os.path.exists(filename):
        exec(open(filename).read())

include('organizations.py')
include('people.py')
include('memberships.py')
include('activity_bill_proposals.py')
include('activity_oral_interpellattions.py')
include('activity_written_interpellattions.py')
include('clean_webcache.py')
