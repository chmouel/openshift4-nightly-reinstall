#!/usr/bin/env bash
set -eux
SUBJECT="${1}"
TEXT="${2}"
SLACK_WEBHOOK_URL=$3
IMAGE_URL=https://upload.wikimedia.org/wikipedia/commons/d/d2/FIRE_BUGLES_-_2.4_%28GOLD%29.png

json=$(cat <<EOF
{
"text": "Pipelines as Code cluster has failed",
"attachments": [
  {
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "${TEXT}"
        },
        "accessory": {
          "type": "image",
          "image_url": "${IMAGE_URL}",
          "alt_text": "From tekton with love"
        }
      }
    ]
  }
]
}
EOF
)
curl -X POST -H 'Content-type: application/json' --data "${json}" $SLACK_WEBHOOK_URL
