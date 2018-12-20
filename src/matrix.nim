import httpclient
import json

type
  MatrixClient* = ref object of RootObj
    client: AsyncHttpClient

  Message = tuple[body: string; sender: string; eventID: string]

let NULLJSON: JsonNode = %*{}


