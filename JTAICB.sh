#!/bin/bash

API_KEY="GEMINIAPIKEY_PLACEDHERE"
MEMORY_FILE="conversation_memory.txt"
VOICE_MEMORY="ai_response.txt"

echo Speak: 

./voicerecord.sh

USER_PROMPT="$(cat output.txt | xargs)"

if [[ -z "$USER_PROMPT" ]]; then
  echo "AI: I didn’t catch that—could you try saying it again?" | tee -a "$MEMORY_FILE" >> "$VOICE_MEMORY"
  ./voice.sh
  exit 0
fi

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

  ESCAPED_TEXT=$(printf '%s' "$TEXT" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\n/\\n/g')
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

echo -n "AI: (thinking...)"

RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d "$REQUEST_BODY")

if echo "$RESPONSE" | grep -q '"role":'; then
  AI_REPLY=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text' | sed 's/"/'\'''\''/g')
  echo -e "\rAI: $AI_REPLY" # \r to overwrite placeholder line
  echo "AI: $AI_REPLY" >> "$MEMORY_FILE"
  echo "$AI_REPLY" >> "$VOICE_MEMORY"
  sed -i 's/\*//g' ai_response.txt
  ./voice.sh 
else
  echo -e "\r[X] API Error:"
  echo "$RESPONSE"
fi

rm tmp_memory.txt
truncate -s 0 ai_response.txt

./JTAICB.sh
