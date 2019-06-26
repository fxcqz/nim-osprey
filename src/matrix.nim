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
import times
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
    roomID*: string
    nextBatch: string
    txID: int
    displayNames: TableRef[string, string]

  Message = tuple[
    body: string; sender: string; eventID: string;
    timestamp: string;
  ]
  ParamT = TableRef[string, string]


proc newMatrixConfig(config: JsonNode): MatrixConfig {.raises: [KeyError].} =
  MatrixConfig(
    username: config["username"].getStr,
    password: config["password"].getStr,
    address:  config["address"].getStr,
    room:     config["room"].getStr,
  )

proc roomName*(self: MatrixConfig): string =
  if self.room.len == 0:
    return ""
  return self.room.split(":")[0][1 .. ^1]

proc newMatrixClient*(jconfig: JsonNode): MatrixClient {.raises: [].} =
  try:
    # newHttpClient can raise Exception when compiling with -d:ssl
    let client = newHttpClient()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})

    let config = newMatrixConfig(jconfig)
    return MatrixClient(client: client, config: config,
                        displayNames: newTable[string, string]())
  except:
    try:
      fatal("Could not load the client config")
    except:
      # sigh... need this try to avoid having to say raises: [Exception]
      discard
    quit(-1)

proc address(self: MatrixClient): string {.raises: [].} =
  self.config.address

proc extractMessages*(self: MatrixClient; data: JsonNode): seq[Message] {.raises: [].} =
  try:
    let roomData: JsonNode = data["rooms"]["join"]
    if self.roomID in roomData:
      let events: JsonNode = roomData[self.roomID]["timeline"]["events"]
      for e in events:
        if "body" in e["content"]:
          result.add((
            e["content"]["body"].getStr,
            e["sender"].getStr,
            e["event_id"].getStr,
            fromUnix(int(e["origin_server_ts"].getInt / 1000)).format("HH:mm:ss"),
          ))
  except KeyError:
    discard

proc makeParams(params: Option[ParamT]): string =
  if params.isNone:
    return ""

  for k, v in params.get:
    result &= &"{k}={v}&"

  result.strip(chars = {'&'})

proc buildUrl(self: MatrixClient; endpoint: string; params: Option[ParamT];
              version: string): string =
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
          version: string = "unstable"): JsonNode =
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
    return %*{}

proc GET(self: MatrixClient; endpoint: string;
         params: Option[ParamT] = none(ParamT);
         version: string = "unstable"): JsonNode =
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
    return %*{}

proc PUT(self: MatrixClient; endpoint: string; data: JsonNode;
         params: Option[ParamT] = none(ParamT);
         version: string = "unstable"): JsonNode =
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
    return %*{}


proc login*(self: var MatrixClient) =
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

proc join*(self: var MatrixClient) {.gcsafe.} =
  let response: JsonNode = self.POST(&"join/{encodeUrl(self.config.room)}", %*{})
  try:
    self.roomID = response["room_id"].getStr
  except KeyError:
    try:
      fatal("Could not join the room")
    except:
      discard
    quit(-1)

proc sync*(self: var MatrixClient): JsonNode =
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
                  mType: string = "m.text") =
  # TODO this proc needs to be changed for anything other that
  # plain text messages
  let data = %*{
    "body": message,
    "msgtype": mType,
  }
  discard self.PUT(&"rooms/{self.roomID}/send/m.room.message/{self.txID}", data)
  self.txID += 1

proc getDisplayName*(self: var MatrixClient; userID: string): string =
  # TODO this needs to invalidate or update when
  # a user nick change event has been detected
  try:
    return self.displayNames[userID]
  except KeyError:
    let response: JsonNode = self.GET(&"profile/{userID}/displayname")
    try:
      let nick = response["displayname"].getStr
      self.displayNames[userID] = nick
      result = nick
    except KeyError:
      result = userID

proc messagesToLines*(self: var MatrixClient; messages: seq[Message]): string =
  # TODO think about how this works now we use labels
  for message in messages:
    let nick = self.getDisplayName(message.sender)
    result &= message.timestamp & " <" & nick & "> " & message.body & "\n"
  result.strip(chars = {'\n'})
