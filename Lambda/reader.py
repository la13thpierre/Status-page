import json
import os

import boto3
from boto3.dynamodb.conditions import Key

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
SITES = json.loads(os.environ["SITES"])
WINDOW = 288


def handler(event, context):
    sites = []
    for url in SITES:
        items = table.query(
            KeyConditionExpression=Key("site").eq(url),
            ScanIndexForward=False,
            Limit=WINDOW,
        )["Items"]
        if not items:
            sites.append({"site": url, "up": None})
            continue
        up_count = sum(1 for i in items if i["up"])
        sites.append(
            {
                "site": url,
                "up": items[0]["up"],
                "status": int(items[0]["status"]),
                "ms": int(items[0]["ms"]),
                "checked": int(items[0]["ts"]),
                "uptime": round(100 * up_count / len(items), 2),
                "history": [1 if i["up"] else 0 for i in reversed(items[:48])],
            }
        )
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"sites": sites}),
    }