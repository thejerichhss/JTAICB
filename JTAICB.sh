#!/bin/bash

API_KEY="GEMINIAPIKEY_PLACEDHERE"
MEMORY_FILE="conversation_memory.txt"

read -p "Enter your prompt: " USER_PROMPT

echo "User: $USER_PROMPT" >> "$MEMORY_FILE"

grep -v -E 'AI: *\{ *"error":' "$MEMORY_FILE" | grep -v '"error":' > tmp_memory.txt

CONTEXT_JSON=""
while IFS= read -r line; do
  ROLE=""
  TEXT="$line"
  if [[ $line == User:* ]]; then
    ROLE="user"
    TEXT="${line#User: }"
  elif [[ $line == AI:* ]]; then
    ROLE="model"
    TEXT="${line#AI: }"
  else
    continue  
  fi

  ESCAPED_TEXT=$(awk -v txt="$TEXT" 'BEGIN { gsub(/"/, "\\\\\"", txt); print txt }')
  CONTEXT_JSON="$CONTEXT_JSON
{
  \"role\": \"$ROLE\",
  \"parts\": [{\"text\": \"$ESCAPED_TEXT\"}]
},"
done < tmp_memory.txt

CONTEXT_JSON=${CONTEXT_JSON%,}

REQUEST_BODY=$(cat <<EOF
{
  "contents": [
    $CONTEXT_JSON
  ]
}
EOF
)

RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d "$REQUEST_BODY")

if echo "$RESPONSE" | grep -q '"role":'; then
  AI_REPLY=$(echo "$RESPONSE" | grep -o '"text": *"[^"]*' | head -1 | cut -d'"' -f4 | sed 's/\\n/ /g')
  echo "AI: $AI_REPLY"
  echo "AI: $AI_REPLY" >> "$MEMORY_FILE"
else
  echo "X API Error:"
  echo "$RESPONSE"
fi

rm tmp_memory.txt

# Relaunch script loop
./ai.sh