# Osprey Copyright (C) 2018 M. Rawcliffe
# This program comes with ABSOLUTELY NO WARRANTY;
# This is free software, and you are welcome to redistribute it
# under certain conditions; see LICENSE.txt for details.

import httpclient
import json

type
  MatrixClient* = ref object of RootObj
    client: AsyncHttpClient

  Message = tuple[body: string; sender: string; eventID: string]

let NULLJSON: JsonNode = %*{}



