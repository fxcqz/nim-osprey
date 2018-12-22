# Osprey Copyright (C) 2018 M. Rawcliffe
# This program comes with ABSOLUTELY NO WARRANTY;
# This is free software, and you are welcome to redistribute it
# under certain conditions; see LICENSE.txt for details.


import httpclient
import json
import tables
import options
import strformat
import strutils
import logging
from uri import encodeUrl

type
  MatrixConfig = object of RootObj
    username: string
    password: string
    address: string
    room: string

  MatrixClient* = ref object of RootObj
    client: HttpClient
    config*: MatrixConfig
    accessToken: string
    userID: string
    roomID: string
    nextBatch: string
    txID: int

  Message = tuple[body: string; sender: string; eventID: string]
  ParamT = TableRef[string, string]


let NULLJSON: JsonNode = %*{}

proc newMatrixConfig(config: JsonNode): MatrixConfig {.raises: [KeyError].} =
  MatrixConfig(
    username: config["username"].getStr,
    password: config["password"].getStr,
    address:  config["address"].getStr,
    room:     config["room"].getStr,
  )

proc newMatrixClient*(jconfig: JsonNode): MatrixClient {.raises: [].} =
  try:
    # newHttpClient can raise Exception when compiling with -d:ssl
    let client = newHttpClient()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})

    let config = newMatrixConfig(jconfig)
    return MatrixClient(client: client, config: config)
  except:
    try:
      fatal("Could not load the client config")
    except:
      # sigh... need this try to avoid having to say raises: [Exception]
      discard
    quit(-1)

proc address(self: MatrixClient): string {.raises: [].} =
  self.config.address

proc makeParams(params: Option[ParamT]): string =
  if params.isNone:
    return ""

  for k, v in params.get:
    result &= &"{k}={v}&"

  result.strip(chars = {'&'})

proc buildUrl(self: MatrixClient; endpoint: string; params: Option[ParamT];
              version: string): string {.raises: [].} =
  var
    url = &"{self.address}/_matrix/client/{version}/{endpoint}"
    concat = '?'

  try:
    let paramString = makeParams(params)

    if len(paramString) > 0:
      url &= &"?{paramString}"
      concat = '&'

    if len(self.accessToken) > 0:
      url &= &"{concat}access_token={self.accessToken}"

    return url
  except UnpackError:
    return ""

proc POST(self: MatrixClient; endpoint: string; data: JsonNode;
          params: Option[ParamT] = none(ParamT);
          version: string = "unstable"): JsonNode {.raises: [].} =
  let url: string = self.buildUrl(endpoint, params, version)
  try:
    let response: Response = self.client.request(
      url, httpMethod = HttpPost, body = $data,
    )
    return response.body.parseJson
  except Exception, HttpRequestError:
    try:
      warn("Post request failed with ", repr(getCurrentException()),
           ": ", getCurrentExceptionMsg())
    except Exception:
      discard
    return NULLJSON

proc GET(self: MatrixClient; endpoint: string;
         params: Option[ParamT] = none(ParamT);
         version: string = "unstable"): JsonNode {.raises: [].} =
  let url: string = self.buildUrl(endpoint, params, version)
  try:
    let response: Response = self.client.request(url, httpMethod = HttpGet)
    return response.body.parseJson
  except Exception, HttpRequestError:
    try:
      warn("Get request failed with ", repr(getCurrentException()),
           ": ", getCurrentExceptionMsg())
    except Exception:
      discard
    return NULLJSON

proc PUT(self: MatrixClient; endpoint: string; data: JsonNode;
         params: Option[ParamT] = none(ParamT);
         version: string = "unstable"): JsonNode {.raises: [].} =
  let url: string = self.buildUrl(endpoint, params, version)
  try:
    let response: Response = self.client.request(
      url, httpMethod = HttpPut, body = $data
    )
    return response.body.parseJson
  except Exception, HttpRequestError:
    try:
      warn("Put request failed with ", repr(getCurrentException()),
           ": ", getCurrentExceptionMsg())
    except Exception:
      discard
    return NULLJSON


proc login*(self: var MatrixClient) {.raises: [].} =
  let
    data = %*{
      "user": self.config.username,
      "password": self.config.password,
      "type": "m.login.password",
    }
    response: JsonNode = self.POST("login", data)

  try:
    self.accessToken = response["access_token"].getStr
    self.userID = response["user_id"].getStr
  except KeyError:
    try:
      fatal("Could not login")
    except:
      discard
    quit(-1)

proc join*(self: var MatrixClient) {.raises: [].} =
  let response: JsonNode = self.POST(&"join/{encodeUrl(self.config.room)}", NULLJSON)
  try:
    self.roomID = response["room_id"].getStr
  except KeyError:
    try:
      fatal("Could not join the room")
    except:
      discard
    quit(-1)

proc sync*(self: var MatrixClient): JsonNode {.raises: [].} =
  var params: Option[ParamT]
  if len(self.nextBatch) > 0:
    params = some[ParamT]({
      "since": self.nextBatch,
    }.newTable)
  else:
    params = none(ParamT)

  let response: JsonNode = self.GET("sync", params)

  try:
    self.nextBatch = response["next_batch"].getStr
  except KeyError:
    # sync failed but we probably don't care
    discard

  return response

proc sendMessage*(self: var MatrixClient; message: string;
                 mType: string = "m.text") {.raises: [].} =
  # TODO this proc needs to be changed for anything other that
  # plain text messages
  let data = %*{
    "body": message,
    "msgtype": mType,
  }
  discard self.PUT(&"rooms/{self.roomID}/send/m.room.message/{self.txID}", data)
  self.txID += 1
