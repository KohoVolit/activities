# recalculates quantiles

import json

import api
import authentication

api.login(authentication.email,authentication.password)

api.post("rpc/refresh_current_people_activity_quantiles",data={})
