import json
import os
import time
import urllib.error
import urllib.request

import boto3
from boto3.dynamodb.conditions import Key

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
sns = boto3.client("sns")

SITES = json.loads(os.environ["SITES"])
KEEP_SECONDS = 7 * 24 * 3600


def check(url):
    start = time.time()
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "status-page-checker"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            code = resp.status
    except urllib.error.HTTPError as err:
        code = err.code
    except Exception:
        code = 0
    ms = int((time.time() - start) * 1000)
    return code, ms


def send_alert(url, up, code):
    topic = os.environ.get("TOPIC_ARN")
    if not topic:
        return
    state = "UP" if up else "DOWN"
    sns.publish(
        TopicArn=topic,
        Subject=f"{url} is {state}",
        Message=f"{url} changed to {state} (status {code}).",
    )


def handler(event, context):
    now = int(time.time())
    for url in SITES:
        code, ms = check(url)
        up = 200 <= code < 400
        prev = table.query(
            KeyConditionExpression=Key("site").eq(url),
            ScanIndexForward=False,
            Limit=1,
        )["Items"]
        was_up = prev[0]["up"] if prev else True
        table.put_item(
            Item={
                "site": url,
                "ts": now,
                "up": up,
                "status": code,
                "ms": ms,
                "expires": now + KEEP_SECONDS,
            }
        )
        if was_up != up:
            send_alert(url, up, code)
    return {"checked": len(SITES)}